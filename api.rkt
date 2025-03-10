(lambda (#:api api #:type type #:enum enum #:array array)
  ; Permission controlled by Role
  ; A user may have multiple roles (e.g. admin and user)
  ; An api requires exactly one role to access
  (enum 'Role
    `[admin]
    `[user]) 

  (type 'User
    `[id uuid]
    `[name string]
    `[roles ,(array 'Roles 'Role)])

  (type `LoginResponse
    `[user User]
    `[token string])

  (api 'register 
    (type `RegisterRequest
      `[username string]
      `[password string])
    'LoginResponse)
  
  (api 'login 
    (type `LoginRequest
      `[username string]
      `[password string])
    'LoginResponse)
  
  (api 'test_auth_echo
    #:auth 'user 
    (type `TestAuthEchoRequest
      `[data string])
    (type `TestAuthEchoResponse
      `[data string])
  )

  (void))