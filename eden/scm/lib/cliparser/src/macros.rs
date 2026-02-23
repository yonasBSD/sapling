/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#[macro_export]
macro_rules! define_flags {
    ( $( $vis:vis struct $name:ident { $( $token:tt )* } )*  ) => {
        $( $crate::_define_flags_impl!(
            input [ $( $token )* ]
            flags []
            arg0 ()
            args []
            varargs ()
            subflags []
            misc ($vis $name 1 false 0)
        ); )*
    };
}

#[doc(hidden)]
#[macro_export]
macro_rules! _define_flags_impl {
    // Nothing left to parse
    ( input []
      flags [ $( ($short:literal, $field:ident, $doc:expr, $type:ty, $default:expr, $argtype:literal) )* ]
      arg0 ( $( $arg0:ident )? )
      args [ $( ($arg:ident, $arg_index:tt, $arg_default:expr) )* ]
      varargs ( $($varargs:ident)? )
      subflags [ $( ($subflag_name:ident, $subflag_type:ty) )* ]
      misc ($vis:vis $name:ident $varargs_offset:tt $has_varargs:tt $min_args:tt)
    ) => {
        $vis struct $name {
            $( #[doc=$doc] pub $field : $type , )*
            $( pub $varargs: Vec<String>, )?
            $( pub $arg0: String, )?
            $( pub $arg: String, )*
            $( pub $subflag_name: $subflag_type, )*
        }

        impl $crate::parser::StructFlags for $name {
            fn flags() -> Vec<$crate::parser::Flag> {
                let flags: Vec<(char, String, String, $crate::parser::Value, String)> = vec![
                    $( ($short, stringify!($field).replace("r#", "").replace("_", "-"), $doc.trim().to_string(), $crate::parser::Value::from($default), $argtype.to_string()), )*
                ];
                #[allow(unused_mut)]
                let mut result: Vec<$crate::parser::Flag> = flags.into_iter().map(Into::into).collect();
                $( result.append(&mut <$subflag_type>::flags()); )*
                result
            }
        }

        impl TryFrom<$crate::parser::ParseOutput> for $name {
            type Error = $crate::anyhow::Error;

            fn try_from(out: $crate::parser::ParseOutput) -> $crate::anyhow::Result<Self> {
                // Validate that required args (None default) don't come after optional args (Some default).
                // This is a configuration error that should be caught during development.
                {
                    let defaults: &[Option<&str>] = &[ $( $arg_default, )* ];
                    let mut seen_optional = false;
                    for default in defaults.iter() {
                        if default.is_some() {
                            seen_optional = true;
                        } else if seen_optional {
                            panic!("invalid positional args: required #[arg]s cannot come after optional #[args]s");
                        }
                    }
                }

                if !$has_varargs && out.args.len() > $varargs_offset {
                    return Err($crate::errors::InvalidArguments.into());
                }
                // Check if we have enough args for required positional parameters.
                // Required args are at indices 1..$min_args+1 (index 0 is reserved for command name).
                // Only check if we have required args ($min_args > 0).
                if $min_args > 0 && out.args.len() < $min_args + 1 {
                    return Err($crate::errors::InvalidArguments.into());
                }

                Ok(Self {
                    $( $field : out.pick::<$type>(&stringify!($field).replace("r#", "").replace("_", "-")), )*
                    $( $varargs: out.args.get($varargs_offset..).map(|v| v.to_vec()).unwrap_or_default(), )?
                    $( $arg0: out.args.get(0).cloned().unwrap_or_default(), )?
                    $( $arg: out.args.get($arg_index).cloned().or_else(|| $arg_default.map(ToString::to_string)).unwrap(), )*
                    $( $subflag_name: <$subflag_type>::try_from(out.clone_only_opts())?, )*
                })
            }
        }
    };

    // Match a field like:
    //
    //    /// description
    //    name: type,
    ( input [ #[doc=$doc:expr] $field:ident : $type:ty, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* (' ', $field, $doc, $type, (<$type>::default()), "") ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    #[argtype("type")]
    //    name: type,
    ( input [ #[doc=$doc:expr] #[argtype($argtype:literal)] $field:ident : $type:ty, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* (' ', $field, $doc, $type, (<$type>::default()), $argtype) ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    #[argtype("type")]
    //    #[short('s')]
    //    name: type,
    ( input [ #[doc=$doc:expr] #[argtype($argtype:literal)] #[short($short:literal)] $field:ident : $type:ty, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* ($short, $field, $doc, $type, (<$type>::default()), $argtype) ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    name: type = default,
    ( input [ #[doc=$doc:expr] $field:ident : $type:ty = $default:tt, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* (' ', $field, $doc, $type, $default, "") ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    #[short('s')]
    //    name: type,
    ( input [ #[doc=$doc:expr] #[short($short:literal)] $field:ident : $type:ty, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* ($short, $field, $doc, $type, (<$type>::default()), "") ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    #[short('s')]
    //    #[argtype("type")]
    //    name: type,
    ( input [ #[doc=$doc:expr] #[short($short:literal)] #[argtype($argtype:literal)] $field:ident : $type:ty, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* ($short, $field, $doc, $type, (<$type>::default()), $argtype) ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    /// description
    //    #[short('s')]
    //    name: type = default,
    ( input [ #[doc=$doc:expr] #[short($short:literal)] $field:ident : $type:ty = $default:tt, $($rest:tt)* ]
      flags [ $( $flags:tt )* ]
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags [ $( $flags )* ($short, $field, $doc, $type, $default, "") ]
            arg0 $arg0
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

    // Match a field like:
    //
    //    #[arg]
    //    name: String,
    ( input [ #[arg] $arg_name:ident : String, $($rest:tt)* ]
      flags $flags:tt
      arg0 $arg0:tt
      args [ $( $rest_args:tt )* ]
      varargs $varargs:tt
      subflags $subflags:tt
      misc ($vis:vis $name:ident $varargs_offset:tt $has_varargs:tt $min_args:tt)
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags $flags
            arg0 $arg0
            args [ $( $rest_args )* ($arg_name, $varargs_offset, None::<&str>) ]
            varargs $varargs
            subflags $subflags
            misc ($vis $name ($varargs_offset + 1) $has_varargs ($min_args + 1))
        );
    };

    // Match a field like:
    //
    //    #[arg]
    //    name: String = "default",
    ( input [ #[arg] $arg_name:ident : String = $default:literal, $($rest:tt)* ]
      flags $flags:tt
      arg0 $arg0:tt
      args [ $( $rest_args:tt )* ]
      varargs $varargs:tt
      subflags $subflags:tt
      misc ($vis:vis $name:ident $varargs_offset:tt $has_varargs:tt $min_args:tt)
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags $flags
            arg0 $arg0
            args [ $( $rest_args )* ($arg_name, $varargs_offset, Some($default)) ]
            varargs $varargs
            subflags $subflags
            misc ($vis $name ($varargs_offset + 1) $has_varargs $min_args)
        );
    };

    // Match a field like:
    //
    //    foo_opts: FooFlags,
    ( input [ $flag_name:ident : $flag_type:ty, $($rest:tt)* ]
      flags $flags:tt
      arg0 $arg0:tt
      args $args:tt
      varargs $varargs:tt
      subflags [ $( $subflags:tt )* ]
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags $flags
            arg0 $arg0
            args $args
            varargs $varargs
            subflags [ $( $subflags )* ( $flag_name, $flag_type ) ]
            misc $misc
        );
    };

    // Match a field like:
    //
    //    #[args]
    //    patterns: Vec<String>,
    ( input [ #[args] $varargs_name:ident : Vec<String>, $($rest:tt)* ]
      flags $flags:tt
      arg0 $arg0:tt
      args $args:tt
      varargs ()
      subflags $subflags:tt
      misc ($vis:vis $name:ident $varargs_offset:tt false $min_args:tt)
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags $flags
            arg0 $arg0
            args $args
            varargs ( $varargs_name )
            subflags $subflags
            misc ($vis $name $varargs_offset true $min_args)
        );
    };

    // Match a field like:
    //
    //    #[command_name]
    //    command_name: String
    ( input [ #[command_name] $arg0:ident : String, $($rest:tt)* ]
      flags $flags:tt
      arg0 ()
      args $args:tt
      varargs $varargs:tt
      subflags $subflags:tt
      misc $misc:tt
    ) => {
        $crate::_define_flags_impl!(
            input [ $( $rest )* ]
            flags $flags
            arg0 ( $arg0 )
            args $args
            varargs $varargs
            subflags $subflags
            misc $misc
        );
    };

}

#[cfg(test)]
mod tests {
    define_flags! {
        struct TestOptions {
            /// bool value
            boo: bool = true,

            /// foo
            foo: bool,

            /// int value
            count: i64 = 12,

            /// name
            long_name: String = "alice",

            /// revisions
            #[short('r')]
            rev: Vec<String>,
        }

        struct AnotherTestOptions {
            /// follow renames
            follow: bool,

            #[args]
            pats: Vec<String>,

            #[command_name]
            name: String,
        }

        struct ComposedOptions {
            /// new value
            new: bool = true,

            /// (duplicated name)
            foo: bool = false,

            test_opts: TestOptions,

            #[args]
            args: Vec<String>,
        }

        struct PositionalArgsWithDefaults {
            /// some flag
            flag: bool,

            #[arg]
            required_arg: String,

            #[arg]
            optional_arg1: String = "default1",

            #[arg]
            optional_arg2: String = "default2",
        }

        struct MultipleOptionalArgs {
            /// some flag
            verbose: bool,

            #[arg]
            first: String = "one",

            #[arg]
            second: String = "two",

            #[arg]
            third: String = "three",
        }
    }

    use crate::parser::Flag;
    use crate::parser::ParseOptions;
    use crate::parser::StructFlags;
    use crate::parser::Value;

    #[test]
    fn test_struct_flags() {
        let flags = TestOptions::flags();
        let expected: Vec<Flag> = vec![
            (None, "boo", "bool value", Value::from(true), ""),
            (None, "foo", "foo", Value::from(false), ""),
            (None, "count", "int value", Value::from(12), ""),
            (None, "long-name", "name", Value::from("alice"), ""),
            (Some('r'), "rev", "revisions", Value::from(Vec::new()), ""),
        ]
        .into_iter()
        .map(Into::into)
        .collect();
        assert_eq!(flags, expected);

        let flags = AnotherTestOptions::flags();
        assert_eq!(flags.len(), 1);
    }

    #[test]
    fn test_struct_parse() {
        let parsed = ParseOptions::new()
            .flags(TestOptions::flags())
            .parse_args(&["cmdname", "--count", "3"])
            .unwrap();
        let parsed = TestOptions::try_from(parsed).unwrap();
        assert!(parsed.boo);
        assert_eq!(parsed.count, 3);
        assert_eq!(parsed.long_name, "alice");
        assert!(parsed.rev.is_empty());

        let parsed = ParseOptions::new()
            .flags(TestOptions::flags())
            .parse_args(&[
                "cmdname",
                "--no-boo",
                "--long-name=bob",
                "--rev=b",
                "-r",
                "a",
            ])
            .unwrap();
        let parsed = TestOptions::try_from(parsed).unwrap();
        assert!(!parsed.boo);
        assert!(!parsed.foo);
        assert_eq!(parsed.count, 12);
        assert_eq!(parsed.long_name, "bob");
        assert_eq!(parsed.rev, vec!["b", "a"]);

        let parsed = ParseOptions::new()
            .flags(TestOptions::flags())
            .parse_args(&["--no-boo", "arg0", "arg1"])
            .unwrap();
        // arg1 is unexpected
        assert!(TestOptions::try_from(parsed).is_err());

        let parsed = ParseOptions::new()
            .flags(AnotherTestOptions::flags())
            .parse_args(&["--no-follow", "foo", "b", "--follow", "c"])
            .unwrap();
        let parsed = AnotherTestOptions::try_from(parsed).unwrap();
        assert!(parsed.follow);
        assert_eq!(parsed.pats, vec!["b", "c"]);
        assert_eq!(parsed.name, "foo");
    }

    #[test]
    fn test_composed_options() {
        let parsed = ParseOptions::new()
            .flags(ComposedOptions::flags())
            .parse_args(&[
                "cmdname",
                "--no-new",
                "--foo=true",
                "1",
                "--count",
                "5",
                "6",
            ])
            .unwrap();
        let parsed = ComposedOptions::try_from(parsed).unwrap();
        assert!(!parsed.new);
        assert_eq!(parsed.test_opts.count, 5);
        assert!(parsed.test_opts.foo);
        assert!(parsed.foo);
        assert_eq!(parsed.args, vec!["1", "6"]);
    }

    #[test]
    fn test_positional_args_with_defaults() {
        // Test with all args provided
        let parsed = ParseOptions::new()
            .flags(PositionalArgsWithDefaults::flags())
            .parse_args(&["cmdname", "required", "opt1", "--flag", "opt2"])
            .unwrap();
        let parsed = PositionalArgsWithDefaults::try_from(parsed).unwrap();
        assert_eq!(parsed.required_arg, "required");
        assert_eq!(parsed.optional_arg1, "opt1");
        assert_eq!(parsed.optional_arg2, "opt2");
        assert!(parsed.flag);

        // Test with only required arg and one optional
        let parsed = ParseOptions::new()
            .flags(PositionalArgsWithDefaults::flags())
            .parse_args(&["cmdname", "required", "custom1"])
            .unwrap();
        let parsed = PositionalArgsWithDefaults::try_from(parsed).unwrap();
        assert_eq!(parsed.required_arg, "required");
        assert_eq!(parsed.optional_arg1, "custom1");
        assert_eq!(parsed.optional_arg2, "default2");

        // Test with only required arg
        let parsed = ParseOptions::new()
            .flags(PositionalArgsWithDefaults::flags())
            .parse_args(&["cmdname", "required"])
            .unwrap();
        let parsed = PositionalArgsWithDefaults::try_from(parsed).unwrap();
        assert_eq!(parsed.required_arg, "required");
        assert_eq!(parsed.optional_arg1, "default1");
        assert_eq!(parsed.optional_arg2, "default2");

        // Test missing required arg fails
        let parsed = ParseOptions::new()
            .flags(PositionalArgsWithDefaults::flags())
            .parse_args(&["cmdname"])
            .unwrap();
        assert!(PositionalArgsWithDefaults::try_from(parsed).is_err());
    }

    #[test]
    fn test_all_optional_args() {
        // Test with no args - all should use defaults
        let parsed = ParseOptions::new()
            .flags(MultipleOptionalArgs::flags())
            .parse_args(&["cmdname"])
            .unwrap();
        let parsed = MultipleOptionalArgs::try_from(parsed).unwrap();
        assert_eq!(parsed.first, "one");
        assert_eq!(parsed.second, "two");
        assert_eq!(parsed.third, "three");
        assert!(!parsed.verbose);

        // Test with some args
        let parsed = ParseOptions::new()
            .flags(MultipleOptionalArgs::flags())
            .parse_args(&["cmdname", "a", "b"])
            .unwrap();
        let parsed = MultipleOptionalArgs::try_from(parsed).unwrap();
        assert_eq!(parsed.first, "a");
        assert_eq!(parsed.second, "b");
        assert_eq!(parsed.third, "three");

        // Test with all args
        let parsed = ParseOptions::new()
            .flags(MultipleOptionalArgs::flags())
            .parse_args(&["cmdname", "x", "y", "z"])
            .unwrap();
        let parsed = MultipleOptionalArgs::try_from(parsed).unwrap();
        assert_eq!(parsed.first, "x");
        assert_eq!(parsed.second, "y");
        assert_eq!(parsed.third, "z");
    }

    define_flags! {
        struct InvalidArgOrder {
            #[arg]
            optional: String = "default",

            #[arg]
            required: String,
        }
    }

    #[test]
    #[should_panic(expected = "invalid positional args")]
    fn test_required_arg_after_optional_panics() {
        let parsed = ParseOptions::new()
            .flags(InvalidArgOrder::flags())
            .parse_args(&["cmdname", "a", "b"])
            .unwrap();
        let args = InvalidArgOrder::try_from(parsed).unwrap();
        let (_, _) = (args.optional, args.required);
    }
}
