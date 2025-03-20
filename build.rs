use std::{fs::File, process::Command};

fn api() -> Result<(), String> {
    let status = Command::new("racket")
        .arg("rust.rkt")
        .stdout(File::create("src/api.rs").map_err(|e| e.to_string())?)
        .status()
        .map_err(|e| e.to_string())?;
    if !status.success() {
        return Err(format!("{}", status));
    }
    Ok(())
}
fn main() {
    println!("cargo:rerun-if-changed=rust.rkt");
    println!("cargo:rerun-if-changed=api.rkt");
    println!("cargo:rerun-if-changed=src");
    if let Err(s) = api() {
        println!("cargo:error=Failed to generate API bindings: {}", s);
    }
}
