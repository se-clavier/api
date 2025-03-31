use std::{fs::File, process::Command};

fn main() {
    let status = Command::new("racket")
        .arg("rust.rkt")
        .stdout(File::create("src/api.rs").expect("failed to create src/api.rs"))
        .status()
        .expect("failed to run racket");
    assert!(status.success(), "racket failed with status: {}", status);
    println!("cargo::rerun-if-changed=rust.rkt");
    println!("cargo::rerun-if-changed=api.rkt");
    println!("cargo::rerun-if-changed=src");
}
