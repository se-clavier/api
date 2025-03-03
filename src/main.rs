use api::APICollection;
use schemars::schema_for;
use serde_json::to_string_pretty;

fn main() {
  println!("{}", to_string_pretty(&schema_for!(APICollection)).unwrap());
}
