require "test_helper"

class DeckSharingTest < ActionDispatch::IntegrationTest
  setup { host! "web" }

  test "deleting a personal copy decrements the original deck count" do
    source = create_deck(user: users(:one))
    source.update!(shared: true)
    sign_in_as(users(:two))

    post "/api/v1/decks/#{source.id}/copy"
    assert_response :created
    copy_id = response.parsed_body["id"]
    assert_equal 1, source.reload.copies_count

    delete "/api/v1/decks/#{copy_id}"
    assert_response :no_content
    assert_equal 0, source.reload.copies_count

    delete "/api/v1/decks/#{copy_id}"
    assert_response :not_found
    assert_equal 0, source.reload.copies_count
  end

  test "preview exposes only published card content without copying the deck" do
    deck = create_deck(user: users(:one))
    card = create_card(deck: deck, example: "A sample.", status: :learned, level: 5)
    path = "/api/v1/decks/#{deck.id}/preview"
    get path
    assert_response :unauthorized

    sign_in_as(users(:two))
    get path
    assert_response :not_found
    deck.update!(shared: true)
    assert_no_difference ["Deck.count", "StudySession.count", -> { deck.reload.copies_count }] do
      get path
      assert_response :success
      assert_equal deck.title, response.parsed_body["title"]
      assert_equal [card.attributes.slice("id", "front", "back", "example")], response.parsed_body["cards"]
    end
    deck.update!(shared: false)
    get path
    assert_response :not_found
  end

  test "only owner can publish and public copies contain fresh progress" do
    owner = users(:one)
    reader = users(:two)
    source = create_deck(user: owner)
    original = create_card(deck: source, status: :learned, level: 5, example: "A sample.")
    path = "/api/v1/decks/#{source.id}"

    sign_in_as(reader)
    post "#{path}/copy"
    assert_response :not_found
    patch "#{path}/sharing", params: { sharing: { shared: true } }, as: :json
    assert_response :not_found

    sign_in_as(owner)
    patch "#{path}/sharing", params: { sharing: { shared: true } }, as: :json
    assert_response :success
    post "#{path}/copy"
    assert_response :not_found

    sign_in_as(reader)
    post "#{path}/copy"
    assert_response :created
    copy = reader.decks.find(response.parsed_body["id"])
    assert_equal source.id, copy.source_deck_id
    assert_equal original.example, copy.cards.sole.example
    assert copy.cards.sole.card_progress.new_card?
    assert_equal 0, copy.cards.sole.card_progress.level
    assert_not copy.shared?
    patch "/api/v1/decks/#{copy.id}/sharing", params: { sharing: { shared: true } }, as: :json
    assert_response :unprocessable_entity
    get "/api/v1/decks/popular"
    assert_equal [source.id], response.parsed_body.pluck("id")

    post "#{path}/copy"
    assert_response :success
    assert_equal copy.id, response.parsed_body["id"]
    assert_equal 1, source.reload.copies_count

    sign_in_as(owner)
    patch "#{path}/sharing", params: { sharing: { shared: false } }, as: :json
    assert_response :success
    delete path
    assert_response :no_content
    assert_nil copy.reload.source_deck_id
    assert_equal original.front, copy.cards.sole.front
    sign_in_as(reader)
    patch "/api/v1/decks/#{copy.id}/sharing", params: { sharing: { shared: true } }, as: :json
    assert_response :unprocessable_entity
  end

  test "catalog is limited to ten shared decks and ranks by additions" do
    sign_in_as(users(:two))
    shared = Array.new(12) do
      deck = create_deck
      deck.update!(shared: true)
      deck
    end
    private_deck = create_deck
    private_deck.update_columns(copies_count: 100)
    get "/api/v1/decks/popular"
    assert_response :success
    ids = response.parsed_body.pluck("id")
    assert_equal 10, ids.uniq.size
    assert_empty ids - shared.map(&:id)

    shared.last.update_columns(copies_count: 2)
    shared.first.update_columns(copies_count: 1)
    get "/api/v1/decks/popular"
    assert_equal [shared.last.id, shared.first.id], response.parsed_body.pluck("id").first(2)
  end
end
