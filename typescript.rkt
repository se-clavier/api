#lang racket

(require "api.rkt")

(define (type-alias type)
  (match type
    ['uint 'number]
    [(? symbol? o) (symbol->string o)]
    [(? string? o) o]))

(define (process doc)
  (define (type name . fields)
    (printf "export interface ~a { ~a }\n"
      name
      (string-join
        (map
          (lambda (f)
            (format "~a: ~a" (car f) (type-alias (cadr f))))
          fields)
        "; "))
    name)
  (define (enum name #:spec [_ '()] . fields)
    (printf "export type ~a = ~a\n"
      name
      (string-join
        (map
          (lambda (f)
            (begin
            )
            (match f
              [`(,name) (format "\"~a\"" name)]
              [`(,name ,value) (format "{ ~a: ~a }" name value)]
              [`(,name . ,values)
                (format "{ ~a: [~a] }"
                  name
                  (string-join
                    (map symbol->string values)
                    ", "))]))
          fields)
        " | "))
    name)
  (define (array name type)
    (printf "export type ~a = ~a[]\n" name type)
    name)
  (define (option type)
    (format "(~a | undefined)" (type-alias type)))
  (define (alias name type)
    (printf "export type ~a = ~a\n" name (type-alias type))
    name)

  (define api-list '())
  (define (api name req res #:auth [auth #f])
    (define (f selector)
      (match selector
        ['collection-enum
         (cond
           [auth `(,name ,req Auth)]
           [else `(,name ,req)])]
        ['api-fn
          (cond
            [auth (printf
              "async ~a(req: ~a): Promise<~a> {
                return this._fetch(async auth => ({ ~a: [req, await auth()] }))
              }\n" name req res name)]
            [else (printf
              "async ~a(req: ~a): Promise<~a> {
                return this._fetch(async _ => ({ ~a: req }))
              }\n" name req res name)])]))
    (set! api-list
      (cons f api-list)))

  (doc #:type type #:enum enum #:api api #:array array #:option option #:alias alias)

  ; Generate template Result type
  (printf "type Result<T> = { Ok: T } | \"Unauthorized\"\n")

  ; Generate Collection
  (apply enum
    (cons 'APICollection
      (map (lambda (f) (f 'collection-enum)) api-list)))

  ; Generate api call
  (printf "export class API {
    private _fetch;
    constructor(fetch: (req: APICollection) => Promise<any>, get_login: () => Promise<LoginRequest>) {
      let auth: Auth | undefined = undefined
      this._fetch = async (req_unauth: (auth: () => Promise<Auth>) => Promise<APICollection>,
                           refresh_auth: boolean = false): Promise<any> => {
        const req = await req_unauth(async () => {
          if (!auth || refresh_auth) {
            let login_res = await this.login(await get_login())
            if (login_res === 'FailureIncorrect') {
              throw new Error(login_res)
            } else {
              auth = login_res.Success
            }
          }
          return auth;
        })

        let res = await fetch(req)
        if (res === 'Unauthorized') {
          return this._fetch(req_unauth, true)
        } else {
          return res.Ok
        }
      }
    }\n")
    (for-each (lambda (f) (f 'api-fn)) api-list)
  (printf "}\n")

  (void))

(process api)

  ; private _fetch;
  ; constructor(fetch: (req: APICollection) => Promise<any>, get_login: () => LoginRequest) {
  ;   let token: Auth | undefined = undefined
  ;   this._fetch = async (req: APICollection, require_auth: boolean, refresh_auth: boolean = false) => {
  ;     if (!token || refresh_auth) {
  ;       let login_res = await this.login(get_login())
  ;       if (login_res) {
  ;         token = login_res.Success
  ;       }
  ;     }
  ;   }
  ; }