#lang racket

(require "api.rkt")

(define (type-alias type)
  (match type
    ['uuid 'number]
    [(? symbol? o) o]))

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
            [auth (printf "async ~a(req: ~a): Promise<~a> { return this.fetch({ ~a: [req, await this.auth()] }); }\n" name req res name)]
            [else (printf "async ~a(req: ~a): Promise<~a> { return this.fetch({ ~a: req }); }\n" name req res name)])]))
    (set! api-list 
      (cons f api-list)))

  (doc #:type type #:enum enum #:api api #:array array)
  
  ; Generate Collection
  (apply enum
    (cons 'APICollection
      (map (lambda (f) (f 'collection-enum)) api-list)))
  
  ; Generate api call
  (printf "export class API {\n")
  (printf "private fetch; private auth; constructor(fetch: (req: APICollection) => Promise<any>, auth: () => Promise<Auth>) { this.fetch = fetch; this.auth = auth }\n")
    (for-each (lambda (f) (f 'api-fn)) api-list)
  (printf "}\n")

  (void))

(process api)