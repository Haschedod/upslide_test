{#
    Normalises the messy date strings found in the raw seeds into a DATE.
    The source data mixes several formats:
      - ISO date            2025-01-16
      - ISO timestamp       2025-01-28 00:00:00
      - slashed ISO         2025/04/06
      - European date       25/01/2025  (DD/MM/YYYY)
    try_strptime returns NULL instead of erroring, so coalesce picks the
    first format that matches. Add new formats here if more appear upstream.
#}
{% macro clean_date(column_name) %}
    coalesce(
        try_strptime({{ column_name }}, '%Y-%m-%d %H:%M:%S'),
        try_strptime({{ column_name }}, '%Y-%m-%d'),
        try_strptime({{ column_name }}, '%Y/%m/%d'),
        try_strptime({{ column_name }}, '%d/%m/%Y'),
        try_strptime({{ column_name }}, '%d-%m-%Y')
    )::date
{% endmacro %}
