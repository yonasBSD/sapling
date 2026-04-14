/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

use std::io;
use std::io::Write;

use backtrace_ext::Backtrace;
use tracing::Event;
use tracing::Subscriber;
use tracing::span;
use tracing_subscriber::Layer;
use tracing_subscriber::layer::Context;
use tracing_subscriber::registry::LookupSpan;

type WriterFactory = Box<dyn Fn() -> Box<dyn Write> + Send + Sync>;

pub struct BacktraceLayer {
    writer_factory: WriterFactory,
}

impl BacktraceLayer {
    pub fn new() -> Self {
        Self {
            writer_factory: Box::new(|| Box::new(io::stderr())),
        }
    }

    pub fn with_writer<F>(mut self, factory: F) -> Self
    where
        F: Fn() -> Box<dyn Write> + Send + Sync + 'static,
    {
        self.writer_factory = Box::new(factory);
        self
    }

    fn write_backtrace(&self, label: &str) {
        // Skip frames from tracing and this crate.
        let bt = Backtrace::capture().skip(7);
        let mut w = (self.writer_factory)();
        let _ = writeln!(w, "Backtrace ({label}):");
        let _ = write!(w, "{bt}");
    }
}

impl<S: Subscriber + for<'a> LookupSpan<'a>> Layer<S> for BacktraceLayer {
    fn on_event(&self, event: &Event<'_>, _ctx: Context<'_, S>) {
        self.write_backtrace(event.metadata().target());
    }

    fn on_enter(&self, id: &span::Id, ctx: Context<'_, S>) {
        let label = ctx
            .span(id)
            .map(|s| format!("enter {}", s.name()))
            .unwrap_or_else(|| "enter <unknown>".into());
        self.write_backtrace(&label);
    }

    fn on_exit(&self, id: &span::Id, ctx: Context<'_, S>) {
        let label = ctx
            .span(id)
            .map(|s| format!("exit {}", s.name()))
            .unwrap_or_else(|| "exit <unknown>".into());
        self.write_backtrace(&label);
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::Mutex;

    use tracing_subscriber::Registry;
    use tracing_subscriber::layer::SubscriberExt;

    use super::*;

    #[derive(Clone, Default)]
    struct Buf(Arc<Mutex<Vec<u8>>>);

    impl Buf {
        fn take(&self) -> String {
            String::from_utf8(std::mem::take(&mut *self.0.lock().unwrap())).unwrap()
        }
    }

    impl Write for Buf {
        fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
            self.0.lock().unwrap().extend_from_slice(buf);
            Ok(buf.len())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    fn setup(buf: &Buf) -> tracing::subscriber::DefaultGuard {
        let layer = BacktraceLayer::new().with_writer({
            let buf = buf.clone();
            move || Box::new(buf.clone())
        });
        tracing::subscriber::set_default(Registry::default().with(layer))
    }

    #[test]
    fn test_event() {
        let buf = Buf::default();
        let _sub = setup(&buf);
        tracing::info!(target: "my_target", "hello");
        let output = buf.take();
        assert!(
            output.contains("(my_target)"),
            "expected target label:\n{output}"
        );
        assert!(output.contains("   0:"), "expected frame 0:\n{output}");
    }

    #[test]
    fn test_span_enter_exit() {
        let buf = Buf::default();
        let _sub = setup(&buf);
        {
            let _span = tracing::info_span!("my_span").entered();
        }
        let output = buf.take();
        assert!(
            output.contains("(enter my_span)"),
            "expected enter label:\n{output}"
        );
        assert!(
            output.contains("(exit my_span)"),
            "expected exit label:\n{output}"
        );
    }
}
