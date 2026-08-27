enum 72271 "DOPSWHS App Filter Combine"
{
    // How a rule's expression combines with the existing record filter when it is applied:
    //   Append  — SetFilter() once (AND-ed with whatever the page set in SourceTableView)
    //   Replace — clear existing filter on this field first (rarely useful)
    //   OR      — when multiple rules from different roles target the same field, their
    //             expressions are concatenated with `|` (set-union) before SetFilter().
    Caption = 'App Filter Combine';
    Extensible = false;

    value(0; "Append")  { Caption = 'Append'; }
    value(1; "Replace") { Caption = 'Replace'; }
    value(2; "OR")      { Caption = 'OR'; }
}
