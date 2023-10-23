alias Plausible.{Repo, ClickhouseRepo, IngestRepo}
alias Plausible.{Site, Sites, Goal, Goals, Stats}

import_if_available(Ecto.Query)
import_if_available(Plausible.Factory)

Logger.configure(level: :warning)

IO.puts(
  IO.ANSI.cyan() <>
    ~S[
        .*$$$$$$s.
       *$$$$$$$$$$$,
      :$$SSS#######S   *$$$$/. $$                      ** $$     l$:
      ,$$SSS#######.   $$   ,$:$$  $$$$$ .S*  $: $$@$* $% $$$$@s :$: s$@$s
      .**$$$#####`     $@$$$$' $l  s-' $:.@*  $| '$@s. $% $$  \$ :$:,$$ *$:
      ,***/`           #$      `$$ %$$%$$ *$$$#`.*sss$ $% $#$$$'  %$ *$sss,
      ,$$'] <> IO.ANSI.reset() <> "\n\n"
)
