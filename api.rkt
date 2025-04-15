#lang racket

(define (api #:api api #:type type #:enum enum #:array array #:option option #:alias alias)
  (begin ; Common definitions
    (alias 'TimeWeek 'string) ; ISO 8601 week
    (alias 'TimeDiff 'string) ; ISO 8601 time difference
    (alias 'Id 'uint) ; universal-unique identifier for indexing

    ; API Result type
    (enum 'Result<T>
      `[Ok T]
      `[Unauthorized])
  )

  (begin ; User
    ; Permission controlled by Role
    ; A user may have multiple roles (e.g. admin and user)
    ; An api requires exactly one role to access
    (enum 'Role
      `[admin]
      `[user]
      #:spec `(
        [rust-derive ,"sqlx::Type"]))

    (type 'Auth
      `[id Id]
      `[roles ,(array 'Roles 'Role)]
      `[signature string])
    ; Template for authenticated requests
    (type 'Authed<T>
      `[auth Auth]
      `[req T])

    ; User's basic information, visible to all
    (type 'User
      `[id Id]
      `[username string])

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
    
    (api 'get_user `Id `User)
    
    (api 'reset_password
      #:auth 'user
      (type `ResetPasswordRequest
        `[password string])
      (enum `ResetPasswordResponse
        `[Success]
        `[FailurePasswordInvalid]))
    
    (api 'reset_password_admin
      #:auth 'admin
      (type `ResetPasswordAdminRequest
        `[id Id]
        `[password string])
      (enum `ResetPasswordAdminResponse
        `[Success]
        `[FailureUserNotFound]))
    
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
    (array 'Rooms 'Room)

    ; Visible to user
    (type 'Spare
      `[id Id] ; unique index, 0 for schedule
      `[stamp Id] ; the index in a week
      `[week TimeWeek] ; the timestamp of Monday 0am at the week
      `[begin_time TimeDiff] ; difference from the week timestamp
      `[end_time TimeDiff] ; difference from the week timestamp
      `[room Room]
      `[assignee ,(option 'User)] ; none if not assigned
      )
    (array 'Spares 'Spare)
    
    ; init spare list
    ; this will erase all existing spares
    (api 'spare_init
      #:auth 'admin
      (type `SpareInitRequest
        `[rooms Rooms]
        `[spares Spares])
      (enum `SpareInitResponse
        `[Success]))

    ; list all rooms and spares within a time range
    (api 'spare_list
      #:auth 'user
      (enum `SpareListRequest
        `[Schedule] ; request the spare schedule, used in spare_questionaire
        `[Week TimeWeek]) ; request the spare list at a certain week
      (type `SpareListResponse
        `[rooms Rooms]
        `[spares Spares]))

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
    
    ; spare questionaire
    (api 'spare_questionaire
      #:auth 'user
      (type `SpareQuestionaireRequest
        `[vacancy 
          ,(array `VacancyArray
            (enum `Vacancy
              `[Available]
              `[Unavailable]))])
      (enum `SpareQuestionaireResponse
        `[Success]))
  )

  (void))

(provide api)