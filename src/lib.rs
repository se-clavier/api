use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(JsonSchema, Serialize, Deserialize)]
pub struct User {
	pub id: u64,
	pub name: String,
}

#[derive(JsonSchema, Serialize, Deserialize)]
pub struct AuthRequest {
	pub username: String,
	pub password: String,
}

#[derive(JsonSchema, Serialize, Deserialize)]
pub struct AuthResponse {
	pub user: User,
	pub token: String,
}

// use enum instead of trait to support JsonSchema and typescript
#[derive(JsonSchema, Serialize, Deserialize)]
pub enum API<Request, Response> {
	Call(Request),
	Return(Response),
}

#[derive(JsonSchema, Serialize, Deserialize)]
pub enum APICollection {
	Auth(API<AuthRequest, AuthResponse>),
}