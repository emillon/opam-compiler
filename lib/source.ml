open! Import

type t = Github_branch of Branch.t | Github_PR of Pull_request.t

let github_pr pr = Github_PR pr

let parse_as_branch s =
  let word = Re.rep1 Re.wordc in
  let branch_name = Re.rep1 Re.any in
  let re_branch =
    Re.compile
      (Re.seq
         [
           Re.bos;
           Re.group word;
           Re.opt (Re.seq [ Re.char '/'; Re.group word ]);
           Re.char ':';
           Re.group branch_name;
           Re.eos;
         ])
  in
  Re.exec_opt re_branch s
  |> option_map (fun g ->
         let user = Re.Group.get g 1 in
         let repo = re_group_get_opt g 2 |> option_get ~default:"ocaml" in
         let branch = Re.Group.get g 3 in
         Github_branch { user; repo; branch })

let parse_as_pr s = option_map github_pr (Pull_request.parse s)

let parse s =
  match parse_as_branch s with Some _ as r -> r | None -> parse_as_pr s

let parse_exn s = parse s |> option_or_fail "Cannot parse source"

let pp ppf = function
  | Github_branch branch ->
      Format.fprintf ppf "Github_branch %a" Branch.pp branch
  | Github_PR pr -> Format.fprintf ppf "Github_PR %a" Pull_request.pp pr

let raw_switch_name source =
  match source with
  | Github_branch { user; repo; branch } ->
      Format.asprintf "%s/%s:%s" user repo branch
  | Github_PR { user; repo; number } ->
      Format.asprintf "%s/%s#%d" user repo number

let global_switch_name source =
  Switch_name.escape_string (raw_switch_name source)

let switch_description source =
  Format.asprintf "[opam-compiler] %s" (raw_switch_name source)

let as_branch source github_client =
  match source with
  | Github_branch branch -> Ok branch
  | Github_PR pr -> Github_client.pr_source_branch github_client pr

let git_url source github_client =
  let open Rresult.R in
  as_branch source github_client >>| fun branch -> Branch.git_url branch

let equal (x : t) y = x = y
