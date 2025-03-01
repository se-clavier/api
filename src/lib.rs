use schemars::JsonSchema;

#[derive(JsonSchema)]
pub struct User {
	pub id: u64,
	pub name: String,
}

#[derive(JsonSchema)]
pub struct LoginRequest {
	pub username: String,
	pub password: String,
}

#[derive(JsonSchema)]
pub struct LoginResponse {
	pub user: User,
	pub token: String,
}

#[derive(JsonSchema)]
pub enum API {
	LoginRequest(LoginRequest),
	LoginResponse(LoginResponse),
}