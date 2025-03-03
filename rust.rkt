#lang racket

(define (type-alias type)
  (match type
    ['uuid 'u64]
    ['string 'String]
    [(? symbol? o) o]))

(define (process doc)
  (define (type name . fields)
    (printf "#[derive(serde::Deserialize, serde::Serialize)] pub struct ~a { ~a }\n"
      name
      (string-join 
        (map 
          (lambda (f) 
            (format "pub ~a: ~a" (car f) (type-alias (cadr f))))
          fields)
        ", "))
    name)
  (define (enum name . fields)
    (printf "#[allow(non_camel_case_types)] #[derive(serde::Deserialize, serde::Serialize)] pub enum ~a { ~a }\n"
      name
      (string-join 
        (map 
          (lambda (f) 
            (format "~a(~a)" (car f) (type-alias (cadr f))))
          fields)
        ", "))
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
    `[code u16]
    `[message string])
  
  ; Generate Collection
  (apply enum
    (cons 'APICollection api-list))
  
  ; Generate Trait and Router
  (printf "#[allow(async_fn_in_trait)]\n")
  (printf "pub trait API {\n")
    (for-api
      (lambda (name req res)
        (printf "async fn ~a(&mut self, req: ~a) -> Result<~a, Error>;\n" name req res)))
    ; Generate handler 
    (printf "async fn handle(&mut self, req: APICollection) -> Result<Box<dyn dyn_serde::Serialize>, Error> {\n")   
      (printf "match req {\n")
        (for-api
          (lambda (name req res)
            (printf "APICollection::~a(req) => Ok(Box::new(self.~a(req).await?)),\n" name name)))
      (printf "}\n")
    (printf "}\n")
  (printf "}\n")

  (void))

(process 
  (eval 
    (read) 
    (make-base-namespace)))