open! Import

type t =
  | Github_branch of Branch.t
  | Github_PR of Pull_request.t
  | Local_source_dir of string

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
  let open Let_syntax.Option in
  let+ g = Re.exec_opt re_branch s in
  let user = Re.Group.get g 1 in
  let repo = re_group_get_opt g 2 |> Option.value ~default:"ocaml" in
  let branch = Re.Group.get g 3 in
  Github_branch { user; repo; branch }

let parse_as_pr s = Option.map github_pr (Pull_request.parse s)

let parse_as_local_source_dir s = Local_source_dir s

let parse s =
  match parse_as_branch s with
  | Some r -> r
  | None -> (
      match parse_as_pr s with
      | Some r -> r
      | None -> parse_as_local_source_dir s )

let pp ppf = function
  | Github_branch branch ->
      Format.fprintf ppf "Github_branch %a" Branch.pp branch
  | Github_PR pr -> Format.fprintf ppf "Github_PR %a" Pull_request.pp pr
  | Local_source_dir p -> Format.fprintf ppf "Local_source_dir %S" p

let raw_switch_name source =
  match source with
  | Github_branch { user; repo; branch } ->
      Format.asprintf "%s/%s:%s" user repo branch
  | Github_PR { user; repo; number } ->
      Format.asprintf "%s/%s#%d" user repo number
  | Local_source_dir p -> p

let global_switch_name source =
  Switch_name.escape_string (raw_switch_name source)

let pp_extra_description ppf = function
  | None -> ()
  | Some s -> Format.fprintf ppf " - %s" s

let extra_description source (client : Github_client.t) =
  match source with
  | Github_branch _ -> None
  | Local_source_dir _ -> None
  | Github_PR pr ->
      let open Let_syntax.Option in
      let+ { title; _ } = Result.to_option (client.pr_info pr) in
      title

let switch_description source client =
  Format.asprintf "[opam-compiler] %s%a" (raw_switch_name source)
    pp_extra_description
    (extra_description source client)

let switch_target source github_client =
  match source with
  | Github_branch branch -> Ok (Branch.git_url branch)
  | Github_PR pr ->
      let open Let_syntax.Result in
      let+ { source_branch; _ } = Github_client.pr_info github_client pr in
      Branch.git_url source_branch
  | Local_source_dir path -> Ok path

let equal (x : t) y = x = y
