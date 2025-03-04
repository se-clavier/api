(lambda (#:api api #:type type #:enum enum)
  (enum 'Role
    `[admin]
    `[user]) 

  (type 'User
    `[id uuid]
    `[name string])
  (type `LoginRequest
    `[username string]
    `[password string])
  (type `LoginResponse
    `[user User]
    `[token string])
  (type `LoginResponse2
    `[user User]
    `[token string])
  
  (api 'login 'LoginRequest 'LoginResponse)
  (api 'login2 'LoginRequest 'LoginResponse2)
  (void))