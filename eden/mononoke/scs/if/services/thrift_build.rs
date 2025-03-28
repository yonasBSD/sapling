// @generated by autocargo

use std::env;
use std::fs;
use std::path::Path;
use thrift_compiler::Config;
use thrift_compiler::GenContext;
const CRATEMAP: &str = "\
eden/mononoke/derived_data/if/derived_data_type.thrift derived_data_type_if //eden/mononoke/derived_data/if:derived_data_type_if-rust
eden/mononoke/megarepo_api/if/megarepo_configs.thrift megarepo_configs //eden/mononoke/megarepo_api/if:megarepo_configs-rust
eden/mononoke/scs/if/source_control.thrift crate //eden/mononoke/scs/if:source_control-rust
fb303/thrift/fb303_core.thrift fb303_core //fb303/thrift:fb303_core-rust
thrift/annotation/cpp.thrift fb303_core->cpp //thrift/annotation:cpp-rust
thrift/annotation/rust.thrift rust //thrift/annotation:rust-rust
thrift/annotation/scope.thrift rust->scope //thrift/annotation:scope-rust
thrift/annotation/thrift.thrift thrift //thrift/annotation:thrift-rust
";
#[rustfmt::skip]
fn main() {
    println!("cargo:rerun-if-changed=thrift_build.rs");
    let out_dir = env::var_os("OUT_DIR").expect("OUT_DIR env not provided");
    let cratemap_path = Path::new(&out_dir).join("cratemap");
    fs::write(cratemap_path, CRATEMAP).expect("Failed to write cratemap");
    Config::from_env(GenContext::Services)
        .expect("Failed to instantiate thrift_compiler::Config")
        .base_path("../../../../..")
        .types_crate("source_control__types")
        .clients_crate("source_control__clients")
        .options("deprecated_default_enum_min_i32,serde")
        .run(["../source_control.thrift"])
        .expect("Failed while running thrift compilation");
}
