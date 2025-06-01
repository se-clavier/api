#lang racket


#|
api.rkt doc

Code Block (No Meaning):
```rkt
(begin ;
;...
)
```

Type Alias Define:
```rkt
(alias 'TypeAlias 'TypeName)
```

Enum Type Define:
```rkt
(enum 'EnumName
  `[Variant1]
  `[Variant2 DataType])
  ;; `DataType` is optional, used to specify the data type of the variant
  ;; `#:spec` is optional, used to specify additional Rust derive attributes 
```

Array Type Define:
```rkt
(array 'ArrayName 'ElementType)
```

Struct Type Define:
```rkt
(type 'TypeName
  `[field1 Type1]
  `[field2 Type2])
```

Option Type Define:
```rkt
(option 'TypeName)
```

API Define:
```rkt
(api 'api-name
  `RequestType
  `ResponseType)
  ;; `RequestType` and `ResponseType` can be type, enum, array, or option
  ;; `#:auth` is optional, used to specify the required role for the API, then the API request must be `Authed<RequestType>` with the specified role.
    ; `#:auth` must be 'role-name.
    ; when the `Authed<RequestType>` not have the required role or expired, the API will return `Unauthorized`
```
|#

(define (api #:api api #:type type #:enum enum #:array array #:option option #:alias alias)
  (begin ; Common definitions
    (alias 'TimeDate 'string) ; ISO 8601 time date
    (alias 'TimeWeek 'string) ; ISO 8601 week
    (alias 'TimeDiff 'string) ; ISO 8601 time difference
    (alias 'Id 'uint) ; universal-unique identifier for indexing
    (array 'TimeWeeks 'TimeWeek)

    ; API Result type
    (enum 'Result<T>
      `[Ok T] ; OK result with data of ResponseType
      `[Unauthorized]) ; Request is unauthorized
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
      `[id Id] ; user id
      `[expire TimeDate] ; expiration time of the auth token
      `[roles Roles] ; roles of the user
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
    #|example
      LoginRequest {
        username: "testuser", // username
        password: "password123", // password
      }
      =>
      LoginResponse::Success(Auth {
        id: 1, // user id
        expire: ...,
        roles: [Role::user, ...], // user roles
        signature: ...,
      })
    |#

    (api 'get_user `Id `User)
    
    (api 'reset_password
      #:auth 'user
      (type `ResetPasswordRequest
        `[password string])
      (enum `ResetPasswordResponse
        `[Success]
        `[FailurePasswordInvalid]))
    
    ; used for testing auth
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
      `[checkin ,(option 'number)] ; checked in by user, number is the late time in minutes
      `[checkout ,(option 'number)] ; checked out by user, number is the early time in minutes
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
    #|example
      SpareInitRequest {
        weeks: ["2023-W01", ...], // list of weeks to init
        rooms: ["room1", ...], // list of rooms
        spares: [
          Spare {
            stamp: 0, // index in the week
            begin_time: "PT08H00M", // 8:00 AM
            end_time: "PT10H00M", // 10:00 AM
            room: "room1", // room name
            assignee: none, // no assignee
            ... // other fields are set by backend
          },...
        ]
      }
      =>
      SpareInitResponse::Success
    |#

    ; list all rooms and spares within a time range
    (api 'spare_list
      #:auth 'user
      (enum `SpareListRequest
        `[User] ; request the spare list for current user
        `[Assigned] ; request the spare list for assigned spares
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
    
    ; trigger auto assignment for certain weeks
    (api 'spare_trigger_assign
      #:auth 'admin
      (type `SpareAutoAssignRequest
        `[weeks TimeWeeks])
      (enum `SpareAutoAssignResponse
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
    
    ; QR code content type (as JSON string)
    (alias 'QRCodeContent 'Auth)
    
    ; User checkin
    ; Backend should first validate the credential.
    (api 'checkin
      #:auth 'user
      (type `CheckinRequest
        `[credential Auth]
        `[id Id])
      (enum `CheckinResponse
        `[InvailidCredential] ; credential is invalid or expired
        `[Early] ; checkin time < start_time - 30min, checkin failed
        `[Intime] ; checkin time in [start_time - 30min, start_time], checkin success
        `[Late number] ; checkin time > start_time, checkin success but marked as late
                       ; return late time, in minutes
        `[Duplicate] ; already checked in, checkin failed
      )) 
    #|example
      CheckinRequest {
        credential: Auth {
          id: 2, // terminal id
          expire: ..., // expiration time of the auth token
          roles: [Role::terminal, ...], // user roles
          signature: ..., // signature for the QR code
        },
        id: 1, // spare id
      }
      =>
      CheckinResponse::Intime // or Early, Late, Duplicate, InvailidCredential
    |#
    
    ; User checkout
    ; Backend should first validate the credential.
    (api 'checkout
      #:auth 'user
      (type `CheckoutRequest
        `[credential Auth]
        `[id Id])
      (enum `CheckoutResponse
        `[InvailidCredential] ; credential is invalid or expired
        `[Early] ; checkout time < end_time - 30min, checkout failed
        `[Intime] ; checkout time in [end_time - 30min, end_time + 30min], checkout success
        `[Late] ; checkout time > end_time + 30min, checkout failed
        `[NotCheckedIn] ; not checked in, checkout failed
        `[Duplicate] ; already checked out, checkout failed
      ))
  )

  (void))

(provide api)