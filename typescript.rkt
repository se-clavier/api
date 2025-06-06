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
            (match f
              [`(,name) (format "{ type: '~a' }" name)]
              [`(,name ,value) (format "{ type: '~a', content: ~a }" name value)]))
          fields)
        " | "))
    name)
  (define (array name type)
    (printf "export type ~a = ~a[]\n" name type)
    name)
  (define (option type)
    (format "(~a | null)" (type-alias type)))
  (define (alias name type)
    (printf "export type ~a = ~a\n" name (type-alias type))
    name)

  (define api-list '())
  (define (api name req res #:auth [auth #f])
    (define (f selector)
      (match selector
        ['collection-enum
         (cond
           [auth `(,name ,(format "Authed<~a>" req))]
           [else `(,name ,req)])]
        ['api-fn
          (cond
            [auth (printf
              "async ~a(req: ~a): Promise<~a> {
                return this._fetch(async auth => ({
                  type: '~a',
                  content: {
                    auth: await auth(),
                    req,
                  }
                }))
              }\n" name req res name)]
            [else (printf
              "async ~a(req: ~a): Promise<~a> {
                return this._fetch(async _ => ({
                  type: '~a',
                  content: req,
                }))
              }\n" name req res name)])]))
    (set! api-list
      (cons f api-list)))

  (doc #:type type #:enum enum #:api api #:array array #:option option #:alias alias)

  ; Generate Collection
  (apply enum
    (cons 'APICollection
      (map (lambda (f) (f 'collection-enum)) api-list)))

  ; Generate api call
  (printf "export class API {
    private _fetch;
    constructor(fetch: (req: APICollection) => Promise<any>, get_auth: (refresh: boolean) => Promise<Auth>) {
      this._fetch = async (req_unauth: (auth: () => Promise<Auth>) => Promise<APICollection>,
                           refresh_auth: boolean = false): Promise<any> => {
        const req = await req_unauth(() => get_auth(refresh_auth))
        const res = await fetch(req)
        if (res.type === 'Unauthorized') {
          return this._fetch(req_unauth, true)
        } else {
          return res.content
        }
      }
    }\n")
    (for-each (lambda (f) (f 'api-fn)) api-list)
  (printf "}\n")

  (void))

(process api)