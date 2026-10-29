# Settings for ala_lint_ruby. Layers are declared top first; the first is the composition. DESIGN.md
# says why each layer exists.
{
  layers: [
    { name: :application, paths: [%r{\Aapp/ala/screens/}, %r{\Aapp/controllers/}, %r{\Aapp/views/(?!components/|elements/)}, %r{\Aconfig/routes\.rb}, %r{\Alib/tasks/}] },
    { name: :features, paths: [%r{\Aapp/ala/features/}] },
    { name: :domain, paths: [%r{\Aapp/ala/domain_abstractions/}, %r{\Aapp/views/components/}] },
    { name: :rules, paths: [%r{\Aapp/ala/rules/}, %r{\Aapp/views/elements/}] },
    # execution models (ChangeFeed, PushLater) run the paradigm interfaces beside them, as in Spray's own layer
    { name: :paradigms, paths: [%r{\Aapp/ala/programming_paradigms/}], peer_ok: true },
    { name: :foundation, paths: [%r{\Aapp/ala/foundation/}, %r{\Aapp/models/}, %r{\Aapp/helpers/}, %r{\Aapp/jobs/}, %r{\Aapp/channels/}], uses: [/\AApplicationRecord\z/], peer_ok: true }
  ],
  identity_models: %w[Cart],
  # ALA Light (kept from V08): R11 (no logic on a composition) is read, not scored, at every tier; DESIGN.md "Inherited: V08's Light reading"
  # a called part receiving data is this variant's design (subset 3), so R11 reports hand-offs only into wired parts
  checks: { r11: { level: :advisory, calls: :wired_only } },
  exclude: [%r{/views/layouts/}],
  min_score: 100
}
