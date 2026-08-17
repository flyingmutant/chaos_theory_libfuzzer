#![no_main]

use libfuzzer_sys::{fuzz_mutator, fuzz_target};
use std::sync::atomic::{AtomicBool, Ordering};

const EFFECTIVE_PREFIX: u8 = 0xa5;

static EFFECTIVE_INPUT_REQUIRED: AtomicBool = AtomicBool::new(false);
static TARGET_HAS_RUN: AtomicBool = AtomicBool::new(false);

#[no_mangle]
pub extern "C" fn LLVMFuzzerRequireEffectiveInput() {
    EFFECTIVE_INPUT_REQUIRED.store(true, Ordering::SeqCst);
}

fn require_effective_input_acknowledgement() {
    assert!(
        EFFECTIVE_INPUT_REQUIRED.load(Ordering::SeqCst),
        "the runtime did not acknowledge required effective-input support"
    );
}

#[no_mangle]
pub unsafe extern "C" fn LLVMFuzzerCustomGetEffectiveInput(
    data: *const u8,
    size: usize,
    out: *mut u8,
    max_out_size: usize,
) -> usize {
    if size == 0 {
        return 0;
    }
    if *data == 0xff {
        return max_out_size + 1;
    }
    if size > max_out_size {
        return size;
    }

    std::ptr::copy_nonoverlapping(data, out, size);
    *out = EFFECTIVE_PREFIX;
    size
}

fuzz_target!(
    init: require_effective_input_acknowledgement(),
    |data: &[u8]| {
        assert!(EFFECTIVE_INPUT_REQUIRED.load(Ordering::SeqCst));
        TARGET_HAS_RUN.store(true, Ordering::SeqCst);

        // Give the target a little real coverage so its initial unit enters
        // the in-memory corpus before the first mutation.
        let payload = data.get(1..).unwrap_or_default();
        if payload.first() == Some(&b'X') {
            std::hint::black_box(payload.len());
        }
    }
);

fuzz_mutator!(
    |data: &mut [u8], size: usize, _max_size: usize, _seed: u32| {
        if TARGET_HAS_RUN.load(Ordering::SeqCst) {
            assert!(size > 0);
            assert_eq!(
                data[0], EFFECTIVE_PREFIX,
                "mutation did not continue from the effective input"
            );
        }

        if size == 1 {
            return 1;
        }

        // Remove the effective-input marker and mutate the payload. The
        // callback restores the marker, so the next mutation in this chain
        // must see it again even though this path discovers no new feature.
        data[0] = 0;
        data[1] = b'X';
        size
    }
);
