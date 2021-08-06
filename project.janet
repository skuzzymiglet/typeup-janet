(declare-project
  :dependencies [{:repo "https://github.com/nate/isatty" :tag "main"}
                 "https://github.com/janet-lang/json"])

(declare-executable :name "typeup" :entry "main.janet" :install true)
