#lang racket

(require "api.rkt")

(define (type-alias type)
  (match type
    ['uint "u64"]
    ['string "String"]
    [(? symbol? o) (symbol->string o)]
    [(? string? o) o]))

(define (process doc)
  (define (type name . fields)
    (printf
      "#[derive(serde::Deserialize, serde::Serialize)]
       pub struct ~a { ~a }\n"
      name
      (string-join
        (map
          (lambda (f)
            (format "pub ~a: ~a" (car f) (type-alias (cadr f))))
          fields)
        ", "))
    name)
  (define (enum name #:spec [spec '()] . fields)
    (printf
      "#[allow(non_camel_case_types)]
       #[derive(~a)]
       #[serde(tag = \"type\", content = \"content\")]
       pub enum ~a { ~a }\n"
      (string-join
        `("serde::Deserialize"
          "serde::Serialize"
          . ,(match (assv 'rust-derive spec)
            [`(rust-derive . ,values) values]
            [_ '()]))
        ", ")
      name
      (string-join
        (map
          (lambda (f)
            (match f
              [`(,name) (format "~a" (type-alias name))]
              [`(,name ,value)
                (format "~a(~a)" name value)]))
          fields)
        ", "))
    name)
  (define (array name type)
    (printf "pub type ~a = Vec<~a>;\n" name type)
    name)
  (define (option type)
    (format "Option<~a>" (type-alias type)))
  (define (alias name type)
    (printf "pub type ~a = ~a;\n" name (type-alias type))
    name)

  (define api-list '())
  (define (api name req res #:auth [auth #f])
    (define (f selector)
      (match selector
        ['collection-enum
         (cond
           [auth `(,name ,(format "Authed<~a>" req))]
           [else `(,name ,req)])]
        ['trait-fn
         (cond
           [auth (printf "async fn ~a(&self, _req: ~a, _auth: Auth) -> ~a { todo!(); }\n" name req res)]
           [else (printf "async fn ~a(&self, _req: ~a) -> ~a { todo!(); } \n" name req res)])]
        ['router-match
          (cond
            [auth (printf
              "APICollection::~a(Authed::<~a>{auth, req}) => {
                Box::new(match self.validate(Role::~a, auth).await {
                  Result::Ok(auth) => Result::Ok(self.~a(req, auth).await),
                  Result::Unauthorized => Result::Unauthorized,
                })
              }\n"
              name req auth name)]
            [else (printf
              "APICollection::~a(req) => {
                Box::new(Result::Ok(self.~a(req).await))
              }\n"
              name name)])]))
    (set! api-list
      (cons f api-list)))

  (doc #:type type #:enum enum #:api api #:array array #:option option #:alias alias)

  ; Generate Collection
  (apply enum
    (cons 'APICollection
      (map (lambda (f) (f 'collection-enum)) api-list)))

  ; Generate Trait and Router
  (printf "#[allow(async_fn_in_trait)]\n")
  (printf "pub trait API {\n")
    ; token validator
    (printf "async fn validate(&self, _role: Role, _auth: Auth) -> Result<Auth> { todo!(); } \n")
    ; api list
    (for-each (lambda (f) (f 'trait-fn)) api-list)
    ; handler
    (printf "async fn handle(&self, req: APICollection) -> Box<dyn dyn_serde::Serialize> {\n")
      (printf "match req {\n")
        (for-each (lambda (f) (f 'router-match)) api-list)
      (printf "}\n")
    (printf "}\n")
  (printf "}\n")

  (void))

(process api)