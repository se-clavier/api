use api::{API, APICollection, AuthRequest, AuthResponse, User};
use serde_json::to_string_pretty;

fn login(req: AuthRequest) -> Result<AuthResponse, ()> {
	Ok(AuthResponse {
		user: User {
			id: 1,
			name: req.username,
		},
		token: "token".to_string(),
	})
}

fn api_wrapper<Request, Response>(
	api: impl Fn(Request) -> Result<Response, ()>,
) -> impl Fn(API<Request, Response>) -> Result<API<Request, Response>, ()> {
	move |param| match param {
		API::Call(req) => Ok(API::Return(api(req)?)),
		API::Return(_) => Err(()),
	}
}

fn api_router(param: APICollection) -> Result<APICollection, ()> {
	Ok(match param {
		APICollection::Auth(param) => api::APICollection::Auth(api_wrapper(login)(param)?),
	})
}

fn main() {
	let req: AuthRequest = AuthRequest {
		username: "username".to_string(),
		password: "password".to_string(),
	};
	let resp: APICollection = api_router(APICollection::Auth(API::Call(req))).unwrap();
	println!("{}", to_string_pretty(&resp).unwrap());
}
