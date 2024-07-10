import React, { useCallback, useEffect, createContext, useState, useContext } from "react";
import { useQueryContext } from "../query-context";
import { formatISO, isAfter, isBefore, nowForSite, parseUTCDate, shiftDays, shiftMonths } from "./util/date";
import { navigateToQuery } from "./query";
import { toggleComparisons } from "./comparison-input";
import { withRouter } from "react-router-dom";

/**
 * Returns whether a keydown or keyup event should be ignored or not.
 *
 * Keybindings are ignored when a modifier key is pressed, for example, if the
 * keybinding is <i>, but the user pressed <Ctrl-i> or <Meta-i>, the event
 * should be discarded.
 *
 * Another case for ignoring a keybinding, is when the user is typing into a
 * form, and presses the keybinding. For example, if the keybinding is <p> and
 * the user types <apple>, the event should also be discarded.
 *
 * @param {*} event - Captured HTML DOM event
 * @return {boolean} Whether the event should be ignored or not.
 *
 */
export function shouldIgnoreKeypress(event) {
    const modifierPressed = event.ctrlKey || event.metaKey || event.altKey || event.keyCode == 229
    const isTyping = event.isComposing || event.target.tagName == "INPUT" || event.target.tagName == "TEXTAREA"

    return modifierPressed || isTyping
}

/**
 * Returns whether the given keybinding has been pressed and should be
 * processed. Events can be ignored based on `shouldIgnoreKeypress(event)`.
 *
 * @param {string} keybinding - The target key to checked, e.g. `"i"`.
 * @return {boolean} Whether the event should be processed or not.
 *
 */
export function isKeyPressed(event, keybinding) {
    const keyPressed = event.key.toLowerCase() == keybinding.toLowerCase()
    return keyPressed && !shouldIgnoreKeypress(event)
}

const KeybindsContext = createContext({ keybinds: new Map(), registerKeybind: (_key, _handler) => { } })

export const KeybindsContextProvider = ({ children }) => {
    const [keybinds, setKeybinds] = useState(new Map());
    const registerKeybind = useCallback((key, handler) => {  setKeybinds((currentKeybinds) => new Map(currentKeybinds.set(key, handler))) }, [])
    return <KeybindsContext.Provider value={{ keybinds, registerKeybind }}>{children}</KeybindsContext.Provider>
}

export const useKeybindsContext = () => { return useContext(KeybindsContext) }

const FilterKeybinds = ({ site, history }) => {
    const { keybinds } = useKeybindsContext();

    const { query } = useQueryContext();

    const handleKeydown = useCallback((e) => {
        if (shouldIgnoreKeypress(e)) return true

        const newSearch = {
            period: false,
            from: false,
            to: false,
            date: false
        };

        const insertionDate = parseUTCDate(site.statsBegin);

        if (e.key === "ArrowLeft") {
            const prevDate = formatISO(shiftDays(query.date, -1));
            const prevMonth = formatISO(shiftMonths(query.date, -1));
            const prevYear = formatISO(shiftMonths(query.date, -12));

            if (query.period === "day" && !isBefore(parseUTCDate(prevDate), insertionDate, query.period)) {
                newSearch.period = "day";
                newSearch.date = prevDate;
            } else if (query.period === "month" && !isBefore(parseUTCDate(prevMonth), insertionDate, query.period)) {
                newSearch.period = "month";
                newSearch.date = prevMonth;
            } else if (query.period === "year" && !isBefore(parseUTCDate(prevYear), insertionDate, query.period)) {
                newSearch.period = "year";
                newSearch.date = prevYear;
            }
        } else if (e.key === "ArrowRight") {
            const now = nowForSite(site)
            const nextDate = formatISO(shiftDays(query.date, 1));
            const nextMonth = formatISO(shiftMonths(query.date, 1));
            const nextYear = formatISO(shiftMonths(query.date, 12));

            if (query.period === "day" && !isAfter(parseUTCDate(nextDate), now, query.period)) {
                newSearch.period = "day";
                newSearch.date = nextDate;
            } else if (query.period === "month" && !isAfter(parseUTCDate(nextMonth), now, query.period)) {
                newSearch.period = "month";
                newSearch.date = nextMonth;
            } else if (query.period === "year" && !isAfter(parseUTCDate(nextYear), now, query.period)) {
                newSearch.period = "year";
                newSearch.date = nextYear;
            }
        }

        const dateRangeKeybinds = {
            d: { date: false, period: 'day' },
            e: { date: formatISO(shiftDays(nowForSite(site), -1)), period: 'day' },
            r: { period: 'realtime' },
            w: { date: false, period: '7d' },
            m: { date: false, period: 'month' },
            y: { date: false, period: 'year' },
            t: { date: false, period: '30d' },
            s: { date: false, period: '6mo' },
            l: { date: false, period: '12mo' },
            a: { date: false, period: 'all' },
        }


        const keybindTarget = dateRangeKeybinds[e.key.toLowerCase()]
        const customKeybindHandler = keybinds.get(e.key.toLowerCase());
        
        if (keybindTarget) {
            navigateToQuery(history, query, { ...newSearch, ...keybindTarget })
        } else if (e.key.toLowerCase() === 'x') {
            toggleComparisons(history, query, site)
        } else if (typeof customKeybindHandler === 'function') {
            
            customKeybindHandler()
        } else if (newSearch.date) {
            navigateToQuery(history, query, newSearch);
        }
    }, [history, query, site, keybinds])


    const register = useCallback(() => {
        document.addEventListener("keydown", handleKeydown)
    }, [handleKeydown]
    );
    const deregister = useCallback(() => {
        document.removeEventListener("keydown", handleKeydown)
    }, [handleKeydown]
    );

    useEffect(() => {
        register()
        return deregister
    }, [register, deregister])

    return <></>;
}

export const FilterKeybindsWrapped = withRouter(FilterKeybinds);