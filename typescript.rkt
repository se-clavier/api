#lang racket

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
  (define (enum name . fields)
    (printf "export type ~a = ~a\n"
      name
      (string-join 
        (map 
          (lambda (f) 
            (format "{ ~a: ~a }" (car f) (type-alias (cadr f))))
          fields)
        " | "))
    name)
  
  (define api-list '())
  (define (api . v)
    (set! api-list 
      (cons v api-list)))
  (define (for-api f)
    (for-each
      (lambda (v)
        (match v 
          [`(,name ,req ,res) (f name req res)]))
      api-list))

  (doc #:type type #:enum enum #:api api)
  
  ; Generate Erorr type
  (type 'Error
    `[code number]
    `[message string])
  
  ; Generate Collection
  (apply enum
    (cons 'APICollection api-list))
  
  ; Generate api call
  (printf "export class API {\n")
  (printf "fetch; constructor(fetch: (req: APICollection) => Promise<any>) { this.fetch = fetch; }\n")
  (for-api
    (lambda (name req res)
      (printf "~a(req: ~a): Promise<~a> { return this.fetch({ ~a: req }); }\n" name req res name)))
  (printf "}\n")

  (void))

(process 
  (eval 
    (read) 
    (make-base-namespace)))