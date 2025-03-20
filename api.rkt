#lang racket

(define (api #:api api #:type type #:enum enum #:array array)
  ; Permission controlled by Role
  ; A user may have multiple roles (e.g. admin and user)
  ; An api requires exactly one role to access
  (enum 'Role
    `[admin]
    `[user]
    #:spec `(
      [rust-derive ,"PartialEq" ,"Eq"])) 

  (type 'Auth
    `[id uuid]
    `[roles ,(array 'Roles 'Role)]
    `[signature string])
  (type 'User
    `[username string])

  (type `LoginResponse
    `[auth Auth]
    `[user User])

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
  
  (type 'Time
    `[week uuid]
    `[day uuid]
    `[num uuid])
  
  (api 'user_queue
    #:auth 'user
    (type 'UserQueueRequest
    `[room_id uuid]
    `[time Time])
    (type `UserQueueResponse
      `[success bool]
      `[rank uuid]))
      
  (api 'user_cancel
    #:auth 'user
    (type 'UserCancelRequest
    `[room_id uuid]
    `[time Time])
    (type `UserCancelResponse
      `[success bool]))
  
  (api 'admin_queue
    #:auth 'admin
    (type 'AdminQueueRequest
    `[room_id uuid]
    `[time Time]
    `[user_id uuid])
    (type `AdminQueueResponse
      `[success bool]
      `[rank uuid]))
      
  (api 'admin_cancel
    #:auth 'admin
    (type 'AdminCancelRequest
    `[room_id uuid]
    `[time Time]
    `[user_id uuid])
    (type `AdminCancelResponse
      `[success bool]))

  (api 'test_auth_echo
    #:auth 'user 
    (type `TestAuthEchoRequest
      `[data string])
    (type `TestAuthEchoResponse
      `[data string]))

  (void))

(provide api)