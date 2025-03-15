#lang racket

(require "api.rkt")

(define (type-alias type)
  (match type
    ['uuid "u64"]
    ['string "String"]
    [(? symbol? o) (symbol->string o)]))

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
  (define (enum name #:spec [spec '()] . fields)
    (printf "#[allow(non_camel_case_types)] #[derive(~a)] pub enum ~a { ~a }\n"
      (string-join
        `("serde::Deserialize"
          "serde::Serialize"
          . ,(match (assv 'rust-derive spec)
            [`('rust-derive . ,values) values]
            [_ '()]))
        ", ")
      name
      (string-join 
        (map 
          (lambda (f) 
            (match f
              [`(,name) (format "~a" (type-alias name))]
              [`(,name . ,value) 
                (format "~a(~a)" 
                  name
                  (string-join
                    (map type-alias value)
                    ", "))]))
          fields)
        ", "))
    name)
  (define (array name type)
    (printf "pub type ~a = Vec<~a>;\n" name type)
    name)
  
  (define api-list '())
  (define (api name req res #:auth [auth #f])
    (define (f selector)
      (match selector
        ['collection-enum 
         (cond 
           [auth `(,name ,req Auth)]
           [else `(,name ,req)])]
        ['trait-fn
         (cond
           [auth (printf "async fn ~a(&mut self, req: ~a, auth: Auth) -> Result<~a, Error>;\n" name req res)]
           [else (printf "async fn ~a(&mut self, req: ~a) -> Result<~a, Error>;\n" name req res)])]
        ; ['trait-fn (printf "async fn ~a(&mut self, req: ~a) -> Result<~a, Error>;\n" name req res)]
        ['router-match 
          (cond 
            [auth (printf "APICollection::~a(req, auth) => { Ok(Box::new(self.~a(req, self.validate(Role::~a, auth).await?).await?)) },\n" name name auth)]
            [else (printf "APICollection::~a(req) => Ok(Box::new(self.~a(req).await?)),\n" name name)])]))
    (set! api-list 
      (cons f api-list)))

  (doc #:type type #:enum enum #:api api #:array array)
  
  ; Generate Erorr type
  (type 'Error
    `[code u16]
    `[message string])
  
  ; Generate Collection
  (apply enum
    (cons 'APICollection
      (map (lambda (f) (f 'collection-enum)) api-list)))
  
  ; Generate Trait and Router
  (printf "#[allow(async_fn_in_trait)]\n")
  (printf "pub trait API {\n")
    ; token validator
    (printf "async fn validate(&self, role: Role, auth: Auth) -> Result<Auth, Error>;\n")
    ; api list
    (for-each (lambda (f) (f 'trait-fn)) api-list)
    ; handler 
    (printf "async fn handle(&mut self, req: APICollection) -> Result<Box<dyn dyn_serde::Serialize>, Error> {\n")   
      (printf "match req {\n")
        (for-each (lambda (f) (f 'router-match)) api-list)
      (printf "}\n")
    (printf "}\n")
  (printf "}\n")

  (void))

(process api)