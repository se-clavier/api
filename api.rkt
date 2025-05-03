#lang racket

(define (api #:api api #:type type #:enum enum #:array array #:option option #:alias alias)
  (begin ; Common definitions
    (alias 'TimeDate 'string) ; ISO 8601 time date
    (alias 'TimeWeek 'string) ; ISO 8601 week
    (alias 'TimeDiff 'string) ; ISO 8601 time difference
    (alias 'Id 'uint) ; universal-unique identifier for indexing
    (array 'TimeWeeks 'TimeWeek)

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
      `[terminal]
      #:spec `(
        [rust-derive ,"sqlx::Type"]))
    (array 'Roles 'Role)

    (type 'Auth
      `[id Id]
      `[expire TimeDate]
      `[roles Roles]
      `[signature string])
    ; Template for authenticated requests
    (type 'Authed<T>
      `[auth Auth]
      `[req T])

    ; User's basic information, visible to all
    (type 'User
      `[id Id]
      `[username string])
    
    ; User's full information, visible to admin
    (type 'UserFull
      `[id Id]
      `[username string]
      `[roles Roles])
    (array 'UserFulls 'UserFull)

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
    
    (api 'test_auth_echo
      #:auth 'user 
      (type `TestAuthEchoRequest
        `[data string])
      (type `TestAuthEchoResponse
        `[data string]))
    
    ; Get all users for admin
    (api 'users_list
      #:auth 'admin
      (type `UsersListRequest)
      (type `UsersListResponse
        `[users UserFulls]))

    (api 'user_set
      #:auth 'admin
      (type `UserSetRequest
        `[user_id Id]
        `[operation 
            ,(enum `UserSetValue
              `[password string]
              `[roles Roles]
              `[delete])]) ; delete spam user
      (enum `UserSetResponse
        `[Success]))
  )

  (begin ; Spare
    ; Room identifier
    (alias 'Room 'string)
    (array 'Rooms 'Room)

    ; Visible to user
    (type 'Spare
      `[id Id] ; unique index
      `[stamp Id] ; the index in a week, same as the index in spare_init list
      `[week TimeWeek] ; the week that this spare belongs to, in ISO 8601 format
      `[begin_time TimeDiff] ; difference from the week timestamp
      `[end_time TimeDiff] ; difference from the week timestamp
      `[room Room]
      `[assignee ,(option 'User)] ; none if not assigned
      )
    (array 'Spares 'Spare)
    
    ; init spare list
    ; this should erase all existing spares
    ; field `spares` contains the list of spares in a week (which means, schedule)
    ; the backend should first store the schedule, for spare_list Schedule request
    ; then, init spares in each week given in field `weeks`
    ; the following fields in spare should be set by backend:
    ; - id: db index
    ; - week: the week in `weeks`, or anything for Schedule
    (api 'spare_init
      #:auth 'admin
      (type `SpareInitRequest
        `[weeks TimeWeeks] ; list of weeks to init
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
    
    ; spare set assignee
    (api 'spare_set_assignee
      #:auth 'admin
      (type `SpareSetAssigneeRequest
        `[id Id]
        `[assignee 
          ,(option 'User)]) ; none if not assigned
      (enum `SpareSetAssigneeResponse
        `[Success]))
  )
  
  (begin ; Check in

    ; Get checkin Credential
    ; Re-use Auth type
    ; Backend should generate a signature for a very short time (e.g. 5 min)
    ; Frontend will get this signature every 1 min
    ; Then display it as a QR code
    (api 'terminal_credential
      #:auth 'terminal
      (type `TerminalCredentialRequest)
      (type `TerminalCredentialResponse
        `[auth Auth]))
    
    ; User checkin
    ; Backend should first validate the credential.
    ; Then find ALL the spares whose `assignee` is the user,
    ; and `start_time` is within [current_time - 30min, current_time + 30min],
    ; and then, checkin all those spares
    (api 'checkin
      #:auth 'user
      (type `CheckinRequest
        `[credential Auth])
      (type `CheckinResponse
        ; list of spares that checked in
        ; empty if no spare is checked in, and frontend should display an error
        `[spares Spares])) 
    
    ; User checkout
    ; Backend should first validate the credential.
    ; Then find ALL the spares whose `assignee` is the user,
    ; and `end_time` is within [current_time - 30min, end_of_current_day],
    ; and has been previously checked in,
    ; and then, checkout all those spares
    (api 'checkout
      #:auth 'user
      (type `CheckoutRequest
        `[credential Auth])
      (type `CheckoutResponse
        ; list of spares that checked out
        ; empty if no spare is checked out, and frontend should display an error
        `[spares Spares]))
  )

  (void))

(provide api)