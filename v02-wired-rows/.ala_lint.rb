# Settings for ala_lint_ruby. Layers are declared top first; the first is the composition. DESIGN.md
# says why each layer exists.
{
  layers: [
    { name: :application, paths: [%r{\Aapp/ala/screens/}, %r{\Aapp/controllers/}, %r{\Aapp/views/(?!components/|elements/)}, %r{\Aconfig/routes\.rb}] },
    { name: :domain, paths: [%r{\Aapp/ala/domain_abstractions/}, %r{\Aapp/views/components/}] },
    { name: :rules, paths: [%r{\Aapp/ala/rules/}, %r{\Aapp/views/elements/}] },
    # execution models (LiveUpdate, PushLater) run the paradigm interfaces beside them, as in Spray's own layer
    { name: :paradigms, paths: [%r{\Aapp/ala/programming_paradigms/}], peer_ok: true },
    { name: :foundation, paths: [%r{\Aapp/ala/foundation/}, %r{\Aapp/models/}, %r{\Aapp/helpers/}, %r{\Aapp/jobs/}, %r{\Aapp/channels/}], uses: [/\AApplicationRecord\z/], peer_ok: true }
  ],
  identity_models: %w[Cart],
  exclude: [%r{/views/layouts/}],
  min_score: 100
}
