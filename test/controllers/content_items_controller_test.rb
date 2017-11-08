require 'test_helper'

class ContentItemsControllerTest < ActionController::TestCase
  include GdsApi::TestHelpers::ContentStore
  include GovukAbTesting::MinitestHelpers

  test 'routing handles paths with no format or locale' do
    assert_routing(
      '/government/news/statement-the-status-of-eu-nationals-in-the-uk',
      controller: 'content_items',
      action: 'show',
      path: 'government/news/statement-the-status-of-eu-nationals-in-the-uk',
    )
  end

  test 'routing handles paths for all supported locales' do
    I18n.available_locales.each do |locale|
      assert_routing(
        "/government/news/statement-the-status-of-eu-nationals-in-the-uk.#{locale}",
        controller: 'content_items',
        action: 'show',
        path: 'government/news/statement-the-status-of-eu-nationals-in-the-uk',
        locale: locale.to_s
      )
    end
  end

  test 'routing handles paths with just format' do
    assert_routing(
      '/government/news/statement-the-status-of-eu-nationals-in-the-uk.atom',
      controller: 'content_items',
      action: 'show',
      path: 'government/news/statement-the-status-of-eu-nationals-in-the-uk',
      format: 'atom',
    )
  end

  test 'routing handles paths with format and locale' do
    assert_routing(
      '/government/news/statement-the-status-of-eu-nationals-in-the-uk.es.atom',
      controller: 'content_items',
      action: 'show',
      path: 'government/news/statement-the-status-of-eu-nationals-in-the-uk',
      format: 'atom',
      locale: 'es'
    )
  end

  test 'routing handles paths with print variant' do
    assert_routing(
      '/government/news/statement-the-status-of-eu-nationals-in-the-uk/print',
      controller: 'content_items',
      action: 'show',
      path: 'government/news/statement-the-status-of-eu-nationals-in-the-uk',
      variant: 'print'
    )
  end

  test "redirects route with invalid parts to base path" do
    content_item = content_store_has_schema_example('travel_advice', 'full-country')
    invalid_part_path = "#{path_for(content_item)}/not-a-valid-part"

    # The content store performs a 301 to the base path when requesting a content item
    # with any part URL. Simulate this by stubbing a request that returns the content
    # item.
    stub_request(:get, %r{#{invalid_part_path}})
      .to_return(status: 200, body: content_item.to_json, headers: {})

    get :show, params: { path: invalid_part_path }

    assert_response :redirect
    assert_redirected_to content_item['base_path']
  end

  test "redirects route for first path to base path" do
    content_item = content_store_has_schema_example('guide', 'guide')
    invalid_part_path = "#{path_for(content_item)}/#{content_item['details']['parts'].first['slug']}"

    stub_request(:get, %r{#{invalid_part_path}}).to_return(status: 200, body: content_item.to_json, headers: {})

    get :show, params: { path: invalid_part_path }

    assert_response :redirect
    assert_redirected_to content_item['base_path']
  end

  test "returns HTML when an unspecific accepts header is requested (eg by IE8 and below)" do
    request.headers["Accept"] = "*/*"
    content_item = content_store_has_schema_example('travel_advice', 'full-country')

    get :show, params: {
      path: path_for(content_item)
    }

    assert_match(/text\/html/, response.headers['Content-Type'])
    assert_response :success
    assert_select '#wrapper'
  end

  test "returns a 406 for XMLHttpRequests without an Accept header set to a supported format" do
    request.headers["X-Requested-With"] = "XMLHttpRequest"
    content_item = content_store_has_schema_example('case_study', 'case_study')

    get :show, params: {
      path: path_for(content_item)
    }

    assert_response :not_acceptable
  end

  test "returns a 406 for unsupported format requests, eg text/javascript" do
    request.headers["Accept"] = "text/javascript"
    content_item = content_store_has_schema_example('case_study', 'case_study')

    get :show, params: {
      path: path_for(content_item)
    }

    assert_response :not_acceptable
  end

  test "gets item from content store" do
    content_item = content_store_has_schema_example('case_study', 'case_study')

    get :show, params: { path: path_for(content_item) }
    assert_response :success
    assert_equal content_item['title'], assigns[:content_item].title
  end

  test "sets the expiry as sent by content-store" do
    content_item = content_store_has_schema_example('coming_soon', 'coming_soon')
    content_store_has_item(content_item['base_path'], content_item, max_age: 20)

    get :show, params: { path: path_for(content_item) }
    assert_response :success
    assert_equal "max-age=20, public", @response.headers['Cache-Control']
  end

  test "honours cache-control private items" do
    content_item = content_store_has_schema_example('coming_soon', 'coming_soon')
    content_store_has_item(content_item['base_path'], content_item, private: true)

    get :show, params: { path: path_for(content_item) }
    assert_response :success
    assert_equal "max-age=900, private", @response.headers['Cache-Control']
  end

  test "renders translated content items in their locale" do
    content_item = content_store_has_schema_example('case_study', 'translated')
    locale = content_item['locale']
    translated_schema_name = I18n.t("content_item.schema_name.case_study", count: 1, locale: locale)

    get :show, params: { path: path_for(content_item, locale), locale: locale }

    assert_response :success
    assert_select "title", %r(#{translated_schema_name})
  end

  test "renders atom feeds" do
    content_item = content_store_has_schema_example('travel_advice', 'full-country')
    get :show, params: { path: path_for(content_item), format: 'atom' }

    assert_response :success
    assert_select "feed title", 'Travel Advice Summary'
  end

  test "renders print variants" do
    content_item = content_store_has_schema_example('travel_advice', 'full-country')
    get :show, params: { path: path_for(content_item), variant: 'print' }

    assert_response :success
    assert_equal request.variant, [:print]
    assert_select ".travel-advice-print"
  end

  test "gets item from content store even when url contains multi-byte UTF8 character" do
    content_item = content_store_has_schema_example('case_study', 'case_study')
    utf8_path    = "government/case-studies/caf\u00e9-culture"
    content_item['base_path'] = "/#{utf8_path}"

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: utf8_path }
    assert_response :success
  end

  test "returns 404 for invalid url" do
    path = 'foreign-travel-advice/egypt]'

    content_store_does_not_have_item('/' + path)

    get :show, params: { path: path }
    assert_response :not_found
  end

  test "returns 404 for item not in content store" do
    path = 'government/case-studies/boost-chocolate-production'

    content_store_does_not_have_item('/' + path)

    get :show, params: { path: path }
    assert_response :not_found
  end

  test "returns 404 if content store falls through to special route" do
    path = 'government/item-not-here'

    content_item = content_store_has_schema_example('special_route', 'special_route')
    content_item['base_path'] = '/government'

    content_store_has_item("/#{path}", content_item)

    get :show, params: { path: path }
    assert_response :not_found
  end

  test "returns 403 for access-limited item" do
    path = 'government/case-studies/super-sekrit-document'
    url = content_store_endpoint + "/content/" + path
    stub_request(:get, url).to_return(status: 403, headers: {})

    get :show, params: { path: path }
    assert_response :forbidden
  end

  test "returns 406 for schema types which don't support provided format" do
    content_item_without_atom = content_store_has_schema_example('case_study', 'case_study')
    get :show, params: { path: path_for(content_item_without_atom), format: 'atom' }

    assert_response :not_acceptable
  end

  test "does not show taxonomy-navigation when no taxons are tagged to Detailed Guides" do
    content_item = content_store_has_schema_example('detailed_guide', 'detailed_guide')
    path = 'government/test/detailed-guide'
    content_item['base_path'] = "/#{path}"
    content_item['links'] = {}

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: path_for(content_item) }
    assert_equal [], @request.variant
    refute_match(/A Taxon/, taxonomy_sidebar)
  end

  test "does not show taxonomy-navigation when page is tagged to mainstream browse" do
    content_item = content_store_has_schema_example('detailed_guide', 'detailed_guide')
    path = 'government/test/detailed-guide'
    content_item['base_path'] = "/#{path}"
    content_item['links'] = {
      'mainstream_browse_pages' => [
        {
          'content_id' => 'something'
        }
      ],
      'taxons' => [
        {
          'title' => 'A Taxon',
          'base_path' => '/a-taxon',
        }
      ]
    }

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: path_for(content_item) }
    assert_equal [], @request.variant
    refute_match(/A Taxon/, taxonomy_sidebar)
  end

  test "show taxonomy-navigation when page is tagged to a world wide taxon" do
    content_item = content_store_has_schema_example('detailed_guide', 'detailed_guide')
    path = 'government/test/detailed-guide'
    content_item['base_path'] = "/#{path}"
    content_item['links'] = {
      'mainstream_browse_pages' => [
        {
          'content_id' => 'something'
        }
      ],
      'taxons' => [
        {
          'title' => 'A Taxon',
          'base_path' => '/world/zanzibar',
        }
      ]
    }

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: path_for(content_item) }

    assert_match(/A Taxon/, taxonomy_sidebar)
  end

  test "shows the taxonomy-navigation if tagged to taxonomy" do
    content_item = content_store_has_schema_example("guide", "guide")
    path = "government/abtest/guide"
    content_item['base_path'] = "/#{path}"
    content_item['links'] = {
      'taxons' => [
        {
          'title' => 'A Taxon',
          'base_path' => '/a-taxon',
        }
      ]
    }

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: path_for(content_item) }
    assert_match(/A Taxon/, taxonomy_sidebar)
  end

  test "Case Studies don't have the taxonomy-navigation" do
    content_item = content_store_has_schema_example('case_study', 'case_study')
    path = 'government/test/case-study'
    content_item['base_path'] = "/#{path}"
    content_item['links'] = {
      'taxons' => [
        {
          'title' => 'A Taxon',
          'base_path' => '/a-taxon',
        }
      ]
    }

    content_store_has_item(content_item['base_path'], content_item)

    get :show, params: { path: path_for(content_item) }
    assert_equal [], @request.variant
    refute_match(/A Taxon/, taxonomy_sidebar)
  end

  test "sets the Access-Control-Allow-Origin header for atom pages" do
    content_store_has_schema_example('travel_advice', 'full-country')
    get :show, params: { path: 'foreign-travel-advice/albania', format: 'atom' }

    assert_equal response.headers["Access-Control-Allow-Origin"], "*"
  end

  test "updates Know your traffic signs description for B variant only" do
    content_item = content_store_has_schema_example("publication", "publication")
    path = "government/publications/know-your-traffic-signs"
    content_item["base_path"] = "/#{path}"
    content_item["description"] = "The current description"

    content_store_has_item(content_item["base_path"], content_item)

    with_variant TrafficSignsSummary: "A", dimension: 81 do
      get :show, params: { path: path_for(content_item) }
      assert_match(/The current description/, response.body)
      refute_match(/Guidance on road traffic signage in Great Britain/, response.body)
    end

    with_variant TrafficSignsSummary: "B", dimension: 81 do
      get :show, params: { path: path_for(content_item) }
      refute_match(/The current description/, response.body)
      assert_match(/Guidance on road traffic signage in Great Britain/, response.body)
    end
  end

  test "Traffic signs summary test does not affect other pages in A" do
    content_item = content_store_has_schema_example("publication", "publication")
    path = "government/publications/some-other-publication"
    content_item["base_path"] = "/#{path}"
    content_item["description"] = "The current description"

    content_store_has_item(content_item["base_path"], content_item)

    setup_ab_variant("TrafficSignsSummary", "A")

    get :show, params: { path: path_for(content_item) }
    assert_match(/The current description/, response.body)
    refute_match(/Guidance on road traffic signage in Great Britain/, response.body)
  end

  test "Traffic signs summary test does not affect other pages in B" do
    content_item = content_store_has_schema_example("publication", "publication")
    path = "government/publications/some-other-publication"
    content_item["base_path"] = "/#{path}"
    content_item["description"] = "The current description"

    content_store_has_item(content_item["base_path"], content_item)

    setup_ab_variant("TrafficSignsSummary", "B")

    get :show, params: { path: path_for(content_item) }
    assert_match(/The current description/, response.body)
    refute_match(/Guidance on road traffic signage in Great Britain/, response.body)
  end

  class SelfAssessmentABTest < ContentItemsControllerTest
    test "shows the original page content on the control version of the self assessment guide" do
      with_variant SelfAssessmentSigninTest: "A" do
        content_item = content_store_has_schema_example('guide', 'guide')
        path = 'log-in-file-self-assessment-tax-return'
        content_item['base_path'] = "/#{path}"
        content_item['details'] = {
          parts: [
            body: "The original part one"
          ]
        }
        content_store_has_item(content_item['base_path'], content_item)

        get :show, params: { path: path_for(content_item) }
        assert @response.body.include?('The original part one')
      end
    end

    test "overwrites content for the first page of the self assessment guide" do
      with_variant SelfAssessmentSigninTest: "B" do
        content_item = content_store_has_schema_example('guide', 'guide')
        path = 'log-in-file-self-assessment-tax-return'
        content_item['base_path'] = "/#{path}"

        content_store_has_item(content_item['base_path'], content_item)

        get :show, params: { path: path_for(content_item) }
        assert @response.body.include?('Sign in to continue')
      end
    end

    test "other guide pages are not overwritten" do
      %w(A B).each do |variant|
        with_variant SelfAssessmentSigninTest: variant do
          content_item = content_store_has_schema_example('guide', 'guide')
          path = 'guide-page'
          content_item['base_path'] = "/#{path}"
          content_item['details'] = {
            parts: [
              body: "The original part one"
            ]
          }

          content_store_has_item(content_item['base_path'], content_item)

          get :show, params: { path: path_for(content_item) }
          assert @response.body.include?('The original part one')
        end
      end
    end

    test "choose_sign_in" do
      with_variant SelfAssessmentSigninTest: "B" do
        content_item = content_store_has_schema_example("guide", "guide")
        content_item["base_path"] = "/log-in-file-self-assessment-tax-return/choose-sign-in"
        content_store_has_item(content_item["base_path"], content_item)

        get :choose_sign_in, params: { path: path_for(content_item) }
        assert_response 200
        assert_not @response.body.include?("You haven't selected an option")
        assert_template("content_items/signin/choose-sign-in")
      end
    end

    test "choose_sign_in with error" do
      with_variant SelfAssessmentSigninTest: "B" do
        content_item = content_store_has_schema_example("guide", "guide")
        content_item["base_path"] = "/log-in-file-self-assessment-tax-return/choose-sign-in"
        content_store_has_item(content_item["base_path"], content_item)

        get :choose_sign_in, params: { path: path_for(content_item), error: true }
        assert_response 200
        assert_template("content_items/signin/choose-sign-in")
        assert @response.body.include?("You haven't selected an option")
      end
    end

    test "sign_in_options with sign-in-option param set" do
      post :sign_in_options, params: { "sign-in-option" => "government-gateway" }

      assert_response :redirect
      assert_redirected_to "https://www.tax.service.gov.uk/account"
    end

    test "sign_in_options with no sign-in-option param set" do
      post :sign_in_options

      assert_response :redirect
      assert_redirected_to "#{choose_sign_in_path}?error=true"
    end

    test "lost_account_details" do
      content_item = content_store_has_schema_example("guide", "guide")
      content_item["base_path"] = "/log-in-file-self-assessment-tax-return/lost-account-details"
      content_store_has_item(content_item["base_path"], content_item)

      get :lost_account_details, params: { path: path_for(content_item) }
      assert_response 200
      assert_template("content_items/signin/lost-account-details")
    end

    test "not_registered" do
      content_item = content_store_has_schema_example("guide", "guide")
      content_item["base_path"] = "/log-in-file-self-assessment-tax-return/not-registered"
      content_store_has_item(content_item["base_path"], content_item)

      get :not_registered, params: { path: path_for(content_item) }
      assert_response 200
      assert_template("content_items/signin/not-registered")
    end
  end

  def path_for(content_item, locale = nil)
    base_path = content_item['base_path'].sub(/^\//, '')
    base_path.gsub!(/\.#{locale}$/, '') if locale
    base_path
  end

  def related_links_sidebar
    Nokogiri::HTML.parse(response.body).at_css(
      shared_component_selector("related_items")
    )
  end

  def taxonomy_sidebar
    Nokogiri::HTML.parse(response.body).at_css(
      shared_component_selector("taxonomy_sidebar")
    )
  end
end
