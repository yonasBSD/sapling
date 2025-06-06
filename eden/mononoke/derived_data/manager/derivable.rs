/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::any::TypeId;
use std::collections::HashMap;
use std::collections::HashSet;
use std::fmt::Debug;
use std::sync::Arc;

use anyhow::Result;
use anyhow::anyhow;
use async_trait::async_trait;
use context::CoreContext;
use derived_data_service_if::DerivedData;
use futures::future::try_join;
use futures::stream;
use futures::stream::StreamExt;
use futures::stream::TryStreamExt;
use mononoke_types::BonsaiChangeset;
use mononoke_types::ChangesetId;
use mononoke_types::DerivableType;

use crate::DerivedDataManager;
use crate::Rederivation;
use crate::SharedDerivationError;
use crate::VisitedDerivableTypesMapStatic;
use crate::context::DerivationContext;

/// Defines how derivation occurs.  Each derived data type must implement
/// `BonsaiDerivable` to describe how to derive a new value from its inputs
/// and how to persist mappings from changesets to derived data.
///
/// As a performance enhancement, a derived data type may also implement the
/// `derive_batch` method of this trait to implement a fast path for deriving
/// data from a batch of changesets.  The default implementation derives each
/// changeset in the batch sequentially.
///
/// As a performance enhancement, a derived data type may also implement the
/// `fetch_batch` method of this trait to implement a fast path for fetching
/// previously-derived and persisted values for a batch of changesets.  The
/// default implementation fetches in separate requests.
#[async_trait]
pub trait BonsaiDerivable: Sized + Send + Sync + Clone + Debug + 'static {
    const VARIANT: DerivableType;
    const NAME: &'static str = Self::VARIANT.name();

    /// Types of derived data types on which this derived data type
    /// depends.
    ///
    /// When performing derivation or backfilling, the derived data manager
    /// will ensure all dependencies are either derived or have been derived
    /// before deriving this derived data type.
    ///
    /// Use the `dependencies!` macro to populate this type.
    type Dependencies: DerivationDependencies;

    /// Types of derived data types which this derived data type
    /// can use as predecessors for the "predecessors optimization".
    ///
    /// This is a technique where you can derive a type from a "predecessor"
    /// type, which allows to parallelize backfilling of the latter type
    /// by using the predecessor type to start deriving future commits before
    /// we have backfilled the latter type.
    /// Example: SkeletonManifest can be used as a predecessor for BSSM.
    ///
    /// Use the `dependencies!` macro to populate this type.
    type PredecessorDependencies: DerivationDependencies;

    /// Derive data for a single changeset.
    ///
    /// If the implementation generates any other data (e.g. manifest nodes
    /// when deriving a manifest root), then it must ensure that all of this
    /// data has been written to its backing store before returning.
    async fn derive_single(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        bonsai: BonsaiChangeset,
        parents: Vec<Self>,
        known: Option<&HashMap<ChangesetId, Self>>,
    ) -> Result<Self>;

    /// Derive data for a batch of changesets.
    ///
    /// This method may be overridden by BonsaiDerivable implementors if
    /// there's a more efficient way to derive a batch of changesets.
    ///
    /// If a gap size is provided, then implementations may choose to
    /// derive only a subset of commits, as long as the gap between
    /// derived commits does not exceed the gap size.
    ///
    /// Not all implementations support gapped derivation, so some
    /// implementations may still derive all items in the batch.  The default
    /// implementation does not support gapped derivation.
    ///
    /// The batch is provided in topological order (ancestors appear before
    /// descendants).
    ///
    /// This method is called after the parents of the roots of the batch of
    /// changesets have been derived, as well as all the data for any of
    /// the dependent derived data types.  These data can be fetched from
    /// the derivation context.
    async fn derive_batch(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        bonsais: Vec<BonsaiChangeset>,
    ) -> Result<HashMap<ChangesetId, Self>> {
        let mut res: HashMap<ChangesetId, Self> = HashMap::new();
        // The default implementation must derive sequentially with no
        // parallelism or concurrency, as dependencies between changesets may
        // cause O(n^2) derivations.
        for bonsai in bonsais {
            let csid = bonsai.get_changeset_id();
            let parents = derivation_ctx
                .fetch_unknown_parents(ctx, Some(&res), &bonsai)
                .await?;
            let derived =
                Self::derive_single(ctx, derivation_ctx, bonsai, parents, Some(&res)).await?;
            res.insert(csid, derived);
        }
        Ok(res)
    }

    /// Derive data for a changeset using other derived data types without
    /// requiring data to be derived for the parents of the changeset.
    ///
    /// Can be used to parallelize backfilling derived data by slicing the commits
    /// of a repository, deriving data for the boundaries of the slices using
    /// this method, and then deriving data for the rest of the commits for all
    /// slices in parallel using the normal derivation path.
    async fn derive_from_predecessor(
        _ctx: &CoreContext,
        _derivation_ctx: &DerivationContext,
        _bonsai: BonsaiChangeset,
    ) -> Result<Self> {
        Err(anyhow!(
            "derive_from_predecessor is not implemented for {}",
            Self::NAME
        ))
    }

    /// Store this derived data as the mapped value for a given changeset.
    ///
    /// Once derivation for a particular changeset is complete, this method
    /// is called so that the mapping from the changeset to the derived
    /// data type can be persisted, allowing it to be fetched again in the
    /// future.
    ///
    /// The derived data manager will ensure that any write caches provided to
    /// `derive_single` or `derive_batch` have been flushed before calling
    /// this method, so it is safe to persistently store the mapping
    /// immediately.
    async fn store_mapping(
        self,
        ctx: &CoreContext,
        derivation: &DerivationContext,
        csid: ChangesetId,
    ) -> Result<()>;

    /// Fetch previously derived and persisted data.
    ///
    /// Returns None if the given changeset has not had derived data
    /// persisted previously.
    async fn fetch(
        ctx: &CoreContext,
        derivation: &DerivationContext,
        csid: ChangesetId,
    ) -> Result<Option<Self>>;

    /// Fetch a batch of previously derived data.
    ///
    /// This method may be overridden by BonsaiDerivable implementors if
    /// there's a more efficient way to fetch a batch of commits.
    ///
    /// Returns a hashmap containing only the commits which have been
    /// previously persisted.  Changesets for which derived data has not
    /// been previously persisted are omitted.
    async fn fetch_batch(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        changeset_ids: &[ChangesetId],
    ) -> Result<HashMap<ChangesetId, Self>> {
        stream::iter(changeset_ids.iter().copied().map(|csid| async move {
            let maybe_derived = Self::fetch(ctx, derivation_ctx, csid).await?;
            Ok(maybe_derived.map(|derived| (csid, derived)))
        }))
        .buffer_unordered(64)
        .try_filter_map(|maybe_value| async move { Ok(maybe_value) })
        .try_collect()
        .await
    }

    fn from_thrift(_data: DerivedData) -> Result<Self>;

    fn into_thrift(_data: Self) -> Result<DerivedData>;
}

#[async_trait]
pub trait DerivationDependencies {
    /// Returns an iterator over all dependencies.
    fn iter() -> impl Iterator<Item = DerivableType>;
    /// Checks that all dependencies have been derived for this
    /// changeset.
    async fn check_dependencies(
        ctx: &CoreContext,
        derivation: &DerivationContext,
        csid: ChangesetId,
    ) -> Result<()>;
    /// Derive all dependent data types for this batch of commits.
    /// The same pre-conditions apply as in derive.rs
    async fn derive_heads(
        ddm: DerivedDataManager,
        ctx: CoreContext,
        heads: Vec<ChangesetId>,
        override_batch_size: Option<u64>,
        rederivation: Option<Arc<dyn Rederivation>>,
        _visited: VisitedDerivableTypesMapStatic<u64, SharedDerivationError>,
    ) -> Result<(), SharedDerivationError>;
    /// Derive all predecessor data types for this batch of commits.
    /// The same pre-conditions apply as in derive.rs
    async fn derive_predecessors(
        ddm: &DerivedDataManager,
        ctx: &CoreContext,
        csid: ChangesetId,
        rederivation: Option<Arc<dyn Rederivation>>,
        visited: &mut HashSet<TypeId>,
    ) -> Result<(), SharedDerivationError>;
}

#[async_trait]
impl DerivationDependencies for () {
    fn iter() -> impl Iterator<Item = DerivableType> {
        std::iter::empty()
    }
    async fn check_dependencies(
        _ctx: &CoreContext,
        _derivation: &DerivationContext,
        _csid: ChangesetId,
    ) -> Result<()> {
        Ok(())
    }
    async fn derive_heads(
        _ddm: DerivedDataManager,
        _ctx: CoreContext,
        _heads: Vec<ChangesetId>,
        _override_batch_size: Option<u64>,
        _rederivation: Option<Arc<dyn Rederivation>>,
        _visited: VisitedDerivableTypesMapStatic<u64, SharedDerivationError>,
    ) -> Result<(), SharedDerivationError> {
        Ok(())
    }
    async fn derive_predecessors(
        _ddm: &DerivedDataManager,
        _ctx: &CoreContext,
        _csid: ChangesetId,
        _rederivation: Option<Arc<dyn Rederivation>>,
        _visited: &mut HashSet<TypeId>,
    ) -> Result<(), SharedDerivationError> {
        Ok(())
    }
}

#[async_trait]
impl<Derivable, Rest> DerivationDependencies for (Derivable, Rest)
where
    Derivable: BonsaiDerivable,
    Rest: DerivationDependencies + 'static,
{
    fn iter() -> impl Iterator<Item = DerivableType> {
        std::iter::once(Derivable::VARIANT).chain(Rest::iter())
    }
    async fn check_dependencies(
        ctx: &CoreContext,
        derivation_ctx: &DerivationContext,
        csid: ChangesetId,
    ) -> Result<()> {
        try_join(
            derivation_ctx.fetch_dependency::<Derivable>(ctx, csid),
            Rest::check_dependencies(ctx, derivation_ctx, csid),
        )
        .await?;
        Ok(())
    }
    async fn derive_heads(
        ddm: DerivedDataManager,
        ctx: CoreContext,
        heads: Vec<ChangesetId>,
        override_batch_size: Option<u64>,
        rederivation: Option<Arc<dyn Rederivation>>,
        visited: VisitedDerivableTypesMapStatic<u64, SharedDerivationError>,
    ) -> Result<(), SharedDerivationError> {
        let _res = try_join(
            ddm.clone().derive_heads_with_visited::<Derivable>(
                ctx.clone(),
                heads.clone(),
                override_batch_size,
                rederivation.clone(),
                visited.clone(),
            ),
            Rest::derive_heads(ddm, ctx, heads, override_batch_size, rederivation, visited),
        )
        .await?;
        Ok(())
    }
    async fn derive_predecessors(
        ddm: &DerivedDataManager,
        ctx: &CoreContext,
        csid: ChangesetId,
        rederivation: Option<Arc<dyn Rederivation>>,
        visited: &mut HashSet<TypeId>,
    ) -> Result<(), SharedDerivationError> {
        let type_id = TypeId::of::<Derivable>();
        if visited.insert(type_id) {
            try_join(
                ddm.derive::<Derivable>(ctx, csid, rederivation.clone()),
                Rest::derive_predecessors(ddm, ctx, csid, rederivation, visited),
            )
            .await?;
            Ok(())
        } else {
            Rest::derive_predecessors(ddm, ctx, csid, rederivation, visited).await
        }
    }
}

#[macro_export]
macro_rules! dependencies {
    () => { () };
    ($dep:ty) => { ( $dep , () ) };
    ($dep:ty, $( $rest:tt )*) => { ( $dep , dependencies!($( $rest )*) ) };
}
