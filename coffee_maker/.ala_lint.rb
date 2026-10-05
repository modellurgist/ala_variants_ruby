# Settings for ala_lint_ruby: Spray's three layers plus the paradigms and Foundation, by directory.
{
  paths: %w[lib bin],
  layers: [
    { name: :application, paths: [%r{\Alib/coffee_maker\.rb\z}, %r{\Abin/}] },
    { name: :domain, paths: [%r{\Alib/coffee_maker/domain_abstractions/}] },
    { name: :paradigms, paths: [%r{\Alib/coffee_maker/programming_paradigms/}], peer_ok: true },
    { name: :foundation, paths: [%r{\Alib/coffee_maker/foundation/}], peer_ok: true }
  ],
  min_score: 100
}
