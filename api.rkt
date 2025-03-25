#lang racket

(define (api #:api api #:type type #:enum enum #:array array #:option option #:alias alias)
  (begin ; Common definitions
    (alias 'Timestamp 'uint) ; unix timestamp
    (alias 'Id 'uint) ; universal-unique identifier for indexing
  )

  (begin ; User
    ; Permission controlled by Role
    ; A user may have multiple roles (e.g. admin and user)
    ; An api requires exactly one role to access
    (enum 'Role
      `[admin]
      `[user]
      #:spec `(
        [rust-derive ,"PartialEq" ,"Eq"]))

    (type 'Auth
      `[id Id]
      `[roles ,(array 'Roles 'Role)]
      `[signature string])

    ; User's basic information, visible to all
    (type 'User
      `[name string])

    ; User management
    (api 'register 
      (type `RegisterRequest
        `[username string]
        `[password string])
      (enum `RegisterResponse
        `[Success Auth] 
        `[FailureUsernameTaken]
        `[FailureUsernameInvalid]
        `[FailurePasswordInvalid]))
    
    (api 'login 
      (type `LoginRequest
        `[username string]
        `[password string])
      (enum `LoginResponse
        `[Success Auth] 
        `[FailureIncorrect]))
    
    (api 'test_auth_echo
      #:auth 'user 
      (type `TestAuthEchoRequest
        `[data string])
      (type `TestAuthEchoResponse
        `[data string]))
  )

  (begin ; Spare
    ; Room identifier
    (alias 'Room 'string)

    ; Visible to user
    (type 'Spare
      `[id Id] ; unique id for indexing
      `[room Room]
      `[begin_time Timestamp]
      `[end_time Timestamp]
      `[assignee ,(option 'User)] ; none if not assigned
      )

    ; list all rooms and spares within a time range
    (api 'spare_list
      #:auth 'user
      (type `SpareListRequest
        `[begin_time Timestamp]
        `[end_time Timestamp])
      (type `SpareListResponse
        `[rooms ,(array 'Rooms 'Room)]
        `[spares ,(array 'Spares 'Spare)]))

    ; take a spare by id
    (api 'spare_take
      #:auth 'user
      (type `SpareTakeRequest
        `[id Id])
      (type `SpareTakeResponse))

    ; return a spare by id
    (api 'spare_return
      #:auth 'user
      (type `SpareReturnRequest
        `[id Id])
      (type `SpareReturnResponse))
  )

  (void))

(provide api)