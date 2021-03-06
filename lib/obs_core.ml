
type term =
  | Var of string
  | FFun of string * term list
[@@deriving variants]

let (let*) = Option.bind

let rec subst (x, y) t =
  match t with
  | FFun (f, args) ->
    FFun (f, List.map (subst (x, y)) args)
  | Var v -> if v = x then y else Var v

let apply s t =
  List.fold_right subst s t

let apply_all s ltt = List.map (fun (x, y) -> apply s x, apply s y) ltt

let rec unify_one t1 t2 =
  match t1, t2 with
  | Var x, Var y -> Some [x, Var y]
  | Var x, FFun (f, args)
  | FFun (f, args), Var x ->
    (* TODO : free variable test should be recursive *)
    if List.exists ((=) (Var x)) args then None
    else Some [x, FFun (f, args)]
  | FFun (f, args1), FFun (g, args2) ->
    if f = g && (List.length args1 = List.length args2) 
    then unify (List.combine args1 args2)
    else None
and unify l =
  match l with
  | [] -> Some []
  | (a, b)::tail ->
    let* m1 = unify_one a b in
    let* m2 = unify (apply_all m1 tail) in
    Some (m2 @ m1)

let rec query qry db =
  match db with
  | [] -> []
  | r::tail ->
    match unify_one qry r with
    | None -> query qry tail
    | Some s ->
      [s] @ (query qry tail)

type rule =
  | Rule of (int ref) * term * term list
  | Know of (int ref) * term
[@@deriving variants]


let rename i t =
  let rec step t =
    match t with
    | Var x -> Var (Printf.sprintf "%s_%d" x i)
    | FFun (f, args) -> FFun (f, List.map step args)
  in 
  step t

let rec str_of_term t =
  match t with
  | Var x -> "?" ^ x
  | FFun (f, []) -> f
  | FFun (f, args) -> f ^ "(" ^ (str_of_terms args) ^ ")"
and str_of_terms lt =
  match lt with
  | [] -> ""
  | x::[] -> str_of_term x
  | x::tail -> str_of_term x ^ ", " ^ (str_of_terms tail)

let str_of_rule r =
  match r with
  | Rule (n, _, _)
  | Know (n, _) -> string_of_int !n
let str_of_rules lr =
  List.fold_left (fun a t -> a ^ (str_of_rule t) ^ " ") " " lr

let str_of_subst (x, t) =
  Printf.sprintf "?%s <- %s" x (str_of_term t)

let str_of_substl l =
  List.fold_left (fun a t -> a ^ (str_of_subst t) ^ " ") " " l

let str_of_substll ll =
  List.fold_left (fun a t -> a ^ (str_of_substl t) ^ " ") " " ll


let rec solve_one qry rules =
  let open List in
  match rules with
  | [] -> []
  | (Rule (n, t, tl) as r)::tail ->
    if !n >= 500 then [] else
      begin
        match unify_one qry (rename !n t) with
        | None -> solve_one qry (tail @ [r])
        | Some s ->
          incr n;
          let sl1 = solve (map (apply s) (map (rename !n) tl)) (tail @ [r]) in
          let sl2 = solve_one qry (tail @ [r]) in
          (List.map (fun x -> x @ s) sl1) @ sl2
      end
  | (Know (n, t) as r)::tail ->
    if !n >= 500 then [] else
      begin
        match unify_one qry (rename !n t) with
        | None -> solve_one qry (tail @ [r])
        | Some s ->
          incr n;
          s::(solve_one qry (tail @ [r]))
      end

and solve qryl rules =
  match qryl with
  | [] ->
    [[]]
  | q::ql ->
    let open List in
    let sols = solve_one q rules in
    map (fun s -> map (fun l -> l @ s) (solve (map (apply s) ql) rules)) sols
    |> List.concat


let print_sols qry sols =
  List.iter (fun t -> print_endline (str_of_term t)) (List.map (fun s -> apply s qry) sols)
