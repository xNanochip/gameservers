#include <sourcemod>
#include <regex>


public void GetPrettyMapName(const char[] map, char[] prettymap, int size)
{
    // copy our mapname into our prettymapname
    strcopy(prettymap, size, map);

    // re/init our regex
    Regex normalizeMapNameRegex = null;
    normalizeMapNameRegex       = CompileRegex("(_(a|b|beta|u|r|v|rc|f|final|comptf|ugc)?[0-9]*[a-z]?$)|([0-9]+[a-z]?$)", 0);

    if (normalizeMapNameRegex == null)
    {
        ThrowError("[prettymap] Couldn't compile regex!");
        return;
    }

    // our match goes in here
    char match[128];

    // get the num of captures for this string
    int caps = MatchRegex(normalizeMapNameRegex, prettymap);
    // if we have 1 or more captures
    if (caps > 0)
    {
        // if we find a substring
        if (GetRegexSubString(normalizeMapNameRegex, 0, match, sizeof(match)))
        {
            LogMessage("match %s", match);
            // hack for refresh maps
            if (StrContains(match, "_f", false) != -1 && StrContains(match, "_final", false) == -1)
            {
                ReplaceString(prettymap, size, match, " refresh", true);
            }
            else
            {
                ReplaceString(prettymap, size, match, "", true);
            }
        }
    }

    // remove underlines and replace with spaces
    ReplaceString(prettymap, size, "_", " ", true);

    LogMessage("Prettymap %s.", prettymap);
}
