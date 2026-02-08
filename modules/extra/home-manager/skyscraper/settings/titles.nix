# Title formatting settings for Skyscraper.
{
  lib,
  skyscraperTypes,
  ...
}: {
  options = {
    keepBrackets = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`true`";
      description = ''
        Keep bracket notes such as `(Europe)` and `[AGA]` in game titles
        when generating the game list.

        When disabled, all bracket content is removed from titles.

        Only affects game list generation, not cache gathering.
      '';
    };

    articlePosition = lib.mkOption {
      type = lib.types.nullOr skyscraperTypes.articlePosition;
      default = null;
      defaultText = lib.literalMD "`end`";
      example = "front";
      description = ''
        Where to position articles ("The", "A") in game titles.

        - `front`: "The Legend of Zelda"
        - `end`: "Legend of Zelda, The"

        Game list sort order is unaffected—titles sort as if articles were absent.
      '';
    };

    forceFilename = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Use the ROM filename (without extension) as the game name instead
        of the title returned by scraping modules.

        If the filename contains bracket notes and `keepBrackets` is true,
        those notes are combined with any brackets from the scraped title,
        which can produce duplicates.
      '';
    };

    template = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "%t [%f];, %P player(s)";
      description = ''
        Template for formatting game names in the game list.

        Supported placeholders:
        - `%t` — title (without bracket info)
        - `%f` — filename (without extension or brackets)
        - `%b` — parenthesized info, e.g. `(USA)`, `(en,fr,de)`
        - `%B` — bracketed info, e.g. `[disk 1 of 2]`, `[AGA]`
        - `%a` — age rating, e.g. `16+`
        - `%d` — developer
        - `%p` — publisher
        - `%r` — rating (`0.0` to `5.0`)
        - `%P` — number of players
        - `%D` — release date (`yyyy-mm-dd`)

        Groups separated by `;` are omitted if all their placeholders are empty.
      '';
    };

    keepDiscInfo = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Retain "Disc N (of M)" information in game titles when bracket
        notes are otherwise removed.

        Only effective when `keepBrackets` is `false`.
        Has no effect when `template` is set.
      '';
    };

    ignoreYearMismatch = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      defaultText = lib.literalMD "`false`";
      description = ''
        Accept scraper matches even when the year in the ROM filename
        differs from the release year in the scraper database.

        By default, mismatched years cause the match to be discarded.
      '';
    };

    bracketSeparator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "] [";
      description = ''
        Replacement string for consecutive `][` sequences in game titles.
        Only used when `keepBrackets` is true and the filename contains
        multiple bracket groups.
      '';
    };

    parenthesisSeparator = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ") (";
      description = ''
        Replacement string for consecutive `)(` sequences in game titles.
        Same behavior as `bracketSeparator` but for parentheses.
      '';
    };
  };
}
