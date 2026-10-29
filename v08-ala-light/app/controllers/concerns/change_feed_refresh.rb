# The page-owned end of the ChangeFeed paradigm (ProgrammingParadigms::ChangeFeed), the same for every
# page: the page's feed in the browser posts a fact of a kind it listens to, the page's screen takes it,
# and the patches its arms made are the answer.
module ChangeFeedRefresh
  extend ActiveSupport::Concern

  def live
    screen.live(params.require(:fact).permit!.to_h)
    render turbo_stream: screen.patches.render(turbo_stream)
  end
end
