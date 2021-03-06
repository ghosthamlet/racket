#lang scheme/base

(require "test-utils.rkt"
         (types subtype numeric-tower union utils abbrev)
         (rep type-rep)
         (env init-envs type-env-structs)
         rackunit
         (for-syntax scheme/base))

(provide subtype-tests)

(define-syntax (subtyping-tests stx)
  (define (single-test stx)
    (syntax-case stx (FAIL)
      [(FAIL t s) (syntax/loc stx (test-check (format "FAIL ~a" '(t s)) (lambda (a b) (not (subtype a b))) t s))]
      [(t s) (syntax/loc stx (test-check (format "~a" '(t s)) subtype t s))]))
  (syntax-case stx ()
    [(_ cl ...)
     (with-syntax ([(new-cl ...) (map single-test (syntax->list #'(cl ...)))])
                  (syntax/loc stx
                              (begin (test-suite "Tests for subtyping"
                                                 new-cl ...))))]))



(define t1 (-mu T (-lst (Un (-v a) T))))
(define t2 (unfold t1))

(define (subtype-tests)
  (subtyping-tests
   ;; trivial examples
   (Univ Univ)
   (-Number Univ)
   (-Boolean Univ)
   (-Symbol Univ)
   (-Void Univ)
   [-Number -Number]
   [(Un (-pair Univ (-lst Univ)) (-val '())) (-lst Univ)]
   [(-pair -Number (-pair -Number (-pair (-val 'foo) (-val '())))) (-lst Univ)]
   [(-pair -Number (-pair -Number (-pair (-val 'foo) (-val '())))) (-lst (Un -Number -Symbol))]
   [(-pair (-val 6) (-val 6)) (-pair -Number -Number)]
   [(-val 6) (-val 6)]
   ;; unions
   [(Un -Number) -Number]
   [(Un -Number -Number) -Number]
   [(Un -Number -Symbol) (Un -Symbol -Number)]
   [(Un (-val 6) (-val 7)) -Number]
   [(Un (-val #f) (Un (-val 6) (-val 7))) (Un -Number (Un -Boolean -Symbol))]
   [(Un (-val #f) (Un (-val 6) (-val 7))) (-mu x (Un -Number (Un -Boolean -Symbol)))]
   [(Un -Number (-val #f) (-mu x (Un -Number -Symbol (make-Listof x))))
    (-mu x (Un -Number -Symbol -Boolean (make-Listof x)))]
   ;; sexps vs list*s of nums
   [(-mu x (Un -Number -Symbol (make-Listof x))) (-mu x (Un -Number -Symbol -Boolean (make-Listof x)))]
   [(-mu x (Un -Number (make-Listof x))) (-mu x (Un -Number -Symbol (make-Listof x)))]
   [(-mu x (Un -Number (make-Listof x))) (-mu y (Un -Number -Symbol (make-Listof y)))]
   ;; a hard one
   [(-mu x (Un -Number (-pair x (-pair -Symbol (-pair x (-val null)))))) -Sexp]
   [t1 (unfold t1)]
   [(unfold t1) t1]
   ;; simple function types
   ((Univ . -> . -Number) (-Number . -> . Univ))
   [(Univ Univ Univ . -> . -Number) (Univ Univ -Number . -> . -Number)]
   ;; simple list types
   [(make-Listof -Number) (make-Listof Univ)]
   [(make-Listof -Number) (make-Listof -Number)]
   [FAIL (make-Listof -Number) (make-Listof -Symbol)]
   [(-mu x (make-Listof x)) (-mu x* (make-Listof x*))]
   [(-pair -Number -Number) (-pair Univ -Number)]
   [(-pair -Number -Number) (-pair -Number -Number)]
   ;; from page 7
   [(-mu t (-> t t)) (-mu s (-> s s))]
   [(-mu s (-> -Number s)) (-mu t (-> -Number (-> -Number t)))]
   ;; polymorphic types
   [(-poly (t) (-> t t)) (-poly (s) (-> s s))]
   [FAIL (make-Listof -Number) (-poly (t) (make-Listof t))]
   [(-poly (a) (make-Listof (-v a))) (make-Listof -Number)]     ;;
   [(-poly (a) -Number) -Number]

   [(-val 6) -Number]
   [(-val 'hello) -Symbol]
   [(-set -Number) (make-Sequence (list -Number))]
   [((Un -Symbol -Number) . -> . -Number) (-> -Number -Number)]
   [(-poly (t) (-> -Number t)) (-mu t (-> -Number t))]
   ;; not subtypes
   [FAIL (-val 'hello) -Number]
   [FAIL (-val #f) -Symbol]
   [FAIL (Univ Univ -Number -Number . -> . -Number) (Univ Univ Univ . -> . -Number)]
   [FAIL (-Number . -> . -Number) (-> Univ Univ)]
   [FAIL (Un -Number -Symbol) -Number]
   [FAIL -Number (Un (-val 6) (-val 11))]
   [FAIL -Symbol (-val 'Sym)]
   [FAIL (Un -Symbol -Number) (-poly (a) -Number)]
   ;; bugs found
   [(Un (-val 'foo) (-val 6)) (Un (-val 'foo) (-val 6))]
   [(-poly (a) (make-Listof (-v a))) (make-Listof (-mu x (Un (make-Listof x) -Number)))]
   [FAIL (make-Listof (-mu x (Un (make-Listof x) -Number))) (-poly (a) (make-Listof a))]
   [(-val -34.2f0) -NegSingleFlonum]
   ;; case-lambda
   [(cl-> [(-Number) -Number] [(-Boolean) -Boolean]) (-Number . -> . -Number)]
   ;; special case for unused variables
   [-Number (-poly (a) -Number)]
   [FAIL (cl-> [(-Number) -Boolean] [(-Boolean) -Number]) (-Number . -> . -Number)]
   ;; varargs
   [(->* (list -Number) Univ -Boolean) (->* (list -Number) -Number -Boolean)]
   [(->* (list Univ) -Number -Boolean) (->* (list -Number) -Number -Boolean)]
   [(->* (list -Number) -Number -Boolean) (->* (list -Number) -Number -Boolean)]
   [(->* (list -Number) -Number -Boolean) (->* (list -Number) -Number Univ)]
   [(->* (list -Number) -Number -Number) (->* (list -Number -Number) -Number)]
   [(->* (list -Number) -Number -Number) (->* (list -Number -Number -Number) -Number)]
   [(->* (list -Number -Number) -Boolean -Number) (->* (list -Number -Number) -Number)]
   [FAIL (->* (list -Number) -Number -Boolean) (->* (list -Number -Number -Number) -Number)]
   [(->* (list -Number -Number) -Boolean -Number) (->* (list -Number -Number -Boolean -Boolean) -Number)]

   [(-poly (a) (cl-> [() a]
                     [(-Number) a]))
    (cl-> [() (-pair -Number (-v b))]
          [(-Number) (-pair -Number (-v b))])]

   [(-values (list -Number)) (-values (list Univ))]

   [(-poly (b) ((Un (make-Base 'foo #'dummy values #'values #f)
                    (-struct #'bar #f
                             (list (make-fld -Number #'values #f) (make-fld b #'values #f))))
                . -> . (-lst b)))
    ((Un (make-Base 'foo #'dummy values #'values #f) (-struct #'bar #f (list (make-fld -Number #'values #f) (make-fld (-pair -Number (-v a)) #'values #f))))
     . -> . (-lst (-pair -Number (-v a))))]
   [(-poly (b) ((-struct #'bar #f (list (make-fld -Number #'values #f) (make-fld b #'values #f))) . -> . (-lst b)))
    ((-struct #'bar #f (list (make-fld -Number #'values #f) (make-fld (-pair -Number (-v a)) #'values #f))) . -> . (-lst (-pair -Number (-v a))))]

   [(-poly (a) (a . -> . (make-Listof a))) ((-v b) . -> . (make-Listof (-v b)))]
   [(-poly (a) (a . -> . (make-Listof a))) ((-pair -Number (-v b)) . -> . (make-Listof (-pair -Number (-v b))))]

   [FAIL (-poly (a b) (-> a a)) (-poly (a b) (-> a b))]
   [FAIL (-poly (a) (-poly (b) (-pair a b))) (-poly (a) (-poly (b) (-pair b a)))]

   ;; The following currently are not subtypes, because they are not replacable
   ;; in an instantiation context. It may be sound for them to be subtypes but
   ;; the implications of that change are unknown.
   [FAIL (-poly (x) (-lst x)) (-poly (x y) (-lst x))]
   [FAIL (-poly (y z) (-lst y)) (-poly (z y) (-lst y))]
   [FAIL (-poly (y) (-poly (z) (-pair y z))) (-poly (y z) (-pair y z))]
   [FAIL (-poly (y z) (-pair y z)) (-poly (y) (-poly (z) (-pair y z)))]


   ;; polymorphic function types should be subtypes of the function top
   [(-poly (a) (a . -> . a)) top-func]
   (FAIL (-> Univ) (null Univ . ->* . Univ))

   [(cl->* (-Number . -> . -String) (-Boolean . -> . -String)) ((Un -Boolean -Number) . -> . -String)]
   [(-struct #'a #f null) (-struct #'a #f null)]
   [(-struct #'a #f (list (make-fld -String #'values #f))) (-struct #'a #f (list (make-fld -String #'values #f)))]
   [(-struct #'a #f (list (make-fld -String #'values #f))) (-struct #'a #f (list (make-fld Univ #'values #f)))]
   [(-val 0.0f0) -SingleFlonum]
   [(-val -0.0f0) -SingleFlonum]
   [(-val 1.0f0) -SingleFlonum]
   [(-pair -String (-lst -String)) (-seq -String)]
   [FAIL (-pair -String (-lst -Symbol)) (-seq -String)]
   [FAIL (-pair -String (-vec -String)) (-seq -String)]
   [(-mpair -String (-mlst -String)) (-seq -String)]
   [FAIL (-mpair -String (-mlst -Symbol)) (-seq -String)]
   [FAIL (-mpair -String (-vec -String)) (-seq -String)]
   [(-mpair -String (-mlst (-val "hello"))) (-seq -String)]

   [(-Param -Byte -Byte) (-Param (-val 0) -Int)]
   [FAIL (-Param -Byte -Byte) (-Param -Int -Int)]
   [(-Param -String -Symbol) (cl->* (-> -Symbol) (-> -String -Void))]

   [(-vec t1) (-vec t2)]
   [(make-HeterogeneousVector (list t1)) (-vec t2)]
   [(make-HeterogeneousVector (list t1 t2)) (make-HeterogeneousVector (list t2 t1))]
   [(-box t1) (-box t2)]
   [(-thread-cell t1) (-thread-cell t2)]
   [(-channel t1) (-channel t2)]
   [(-mpair t1 t2) (-mpair t2 t1)]
   [(-HT t1 t2) (-HT t2 t1)]
   [(make-Prompt-Tagof t1 t2) (make-Prompt-Tagof t2 t1)]
   [(make-Continuation-Mark-Keyof t1) (make-Continuation-Mark-Keyof t2)]

   [(-val 5) (-seq -Nat)]
   [(-val 5) (-seq -Byte)]
   [-Index (-seq -Index)]
   [-NonNegFixnum (-seq -NonNegFixnum)]
   [-Index (-seq -Nat)]
   [FAIL (-val -5) (-seq -Nat)]
   [FAIL -Fixnum (-seq -Fixnum)]
   [FAIL -NonNegFixnum (-seq -Index)]
   [FAIL (-val 5.0) (-seq -Nat)]

   [(-polydots (a) (->... (list Univ) (a a) (make-ValuesDots null a 'a)))
    (-polydots (a) (->... (list -String) (a a) (make-ValuesDots null a 'a)))]

   [(-polydots (a) (->... null (Univ a) (make-ValuesDots (list (-result a)) a 'a)))
    (-polydots (a) (->... null (-String a) (make-ValuesDots (list (-result a)) a 'a)))]

   [(-polydots (a) (->... null (a a) (make-ValuesDots (list (-result -String)) -String 'a)))
    (-polydots (a) (->... null (a a) (make-ValuesDots (list (-result Univ)) Univ 'a)))]

   [(-polydots (a) (->... null (Univ a) (-values (list Univ))))
    (->* null Univ Univ)]


   [(-polydots (a) (->... null (a a) (make-ListDots a 'a)))
    (-> -String -Symbol (-Tuple (list -String -Symbol)))]
   [(-> -String -Symbol (-Tuple (list -String -Symbol)))
    (-polydots (a) (-> -String -Symbol (-lst (Un -String -Symbol))))]

   [(-polydots (a) (->... null (a a) (make-ListDots a 'a)))
    (-poly (a b) (-> a b (-Tuple (list a b))))]

   [(-polydots (b a) (-> (->... (list b) (a a) (make-ValuesDots (list (-result b)) a 'a)) Univ))
    (-polydots (a) (-> (->... (list) (a a) (make-ValuesDots null a 'a)) Univ))]

   [(-polydots (a) (->... (list) (a a) (make-ListDots a 'a)))
    (-polydots (b a) (->... (list b) (a a) (-pair b (make-ListDots a 'a))))]

   [(-> Univ -Boolean : (-FS (-filter -Symbol 0) (-not-filter -Symbol 0)))
    (-> Univ -Boolean : (-FS -top -top))]
   [(-> Univ -Boolean : (-FS -bot -bot))
    (-> Univ -Boolean : (-FS (-filter -Symbol 0) (-not-filter -Symbol 0)))]
   [(-> Univ -Boolean : (-FS (-filter -Symbol 0) (-not-filter -Symbol 0)))
    (-> (Un -Symbol -String) -Boolean : (-FS (-filter -Symbol 0) (-not-filter -Symbol 0)))]
   [FAIL
    (-> Univ -Boolean : (-FS (-filter -Symbol 0) (-not-filter -Symbol 0)))
    (-> Univ -Boolean : (-FS (-filter -String 0) (-not-filter -String 0)))]

   [FAIL (make-ListDots (-box (make-F 'a)) 'a) (-lst (-box Univ))]
   [(make-ListDots (-> -Symbol (make-F 'a)) 'a) (-lst (-> -Symbol Univ))]

   ))

(define-go
  subtype-tests)
