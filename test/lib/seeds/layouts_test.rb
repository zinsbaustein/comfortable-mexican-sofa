require_relative '../../test_helper'

class SeedsLayoutsTest < ActiveSupport::TestCase

  DEFAULT_HTML = <<~HTML
    <html>
      <body>
        {{ cms:markdown content }}
      </body>
    </html>

  HTML

  NESTED_HTML = <<~HTML
    {{ cms:file thumbnail }}
    <div class="left">{{ cms:markdown left }}</div>
    <div class="right">{{ cms:markdown right }}</div>

  HTML

  def test_creation
    Comfy::Cms::Layout.delete_all

    assert_difference 'Comfy::Cms::Layout.count', 2 do
      ComfortableMexicanSofa::Seeds::Layout::Importer.new('sample-site', 'default-site').import!
    end

    assert layout = Comfy::Cms::Layout.where(identifier: "default").first
    assert_equal "Default Seed Layout", layout.label
    assert_equal DEFAULT_HTML,          layout.content
    assert_equal "body{color: red}\n",  layout.css
    assert_equal "// default js\n\n",   layout.js

    assert nested_layout = Comfy::Cms::Layout.where(identifier: "nested").first
    assert_equal layout, nested_layout.parent
    assert_equal "Nested Seed Layout",  nested_layout.label
    assert_equal NESTED_HTML,           nested_layout.content
    assert_equal "div{float:left}\n",   nested_layout.css
    assert_equal "// nested js\n\n",    nested_layout.js
  end

  def test_update
    layout        = comfy_cms_layouts(:default)
    nested_layout = comfy_cms_layouts(:nested)
    child_layout  = comfy_cms_layouts(:child)
    layout.update_column(:updated_at, 10.years.ago)
    nested_layout.update_column(:updated_at, 10.years.ago)
    child_layout.update_column(:updated_at, 10.years.ago)

    assert_count_difference [Comfy::Cms::Layout], -1 do
      ComfortableMexicanSofa::Seeds::Layout::Importer.new('sample-site', 'default-site').import!

      layout.reload
      assert_equal 'Default Seed Layout', layout.label
      assert_equal DEFAULT_HTML,          layout.content
      assert_equal "body{color: red}\n",  layout.css
      assert_equal "// default js\n\n",   layout.js
      assert_equal 0,                     layout.position

      nested_layout.reload
      assert_equal layout,                nested_layout.parent
      assert_equal "Nested Seed Layout",  nested_layout.label
      assert_equal NESTED_HTML,           nested_layout.content
      assert_equal "div{float:left}\n",   nested_layout.css
      assert_equal "// nested js\n\n",    nested_layout.js
      assert_equal 42,                    nested_layout.position

      assert_nil Comfy::Cms::Layout.where(identifier: "child").first
    end
  end

  def test_update_ignore
    layout = comfy_cms_layouts(:default)
    layout_path       = File.join(ComfortableMexicanSofa.config.seeds_path, 'sample-site', 'layouts', 'default')
    content_file_path = File.join(layout_path, 'content.html')

    assert layout.updated_at >= File.mtime(content_file_path)

    ComfortableMexicanSofa::Seeds::Layout::Importer.new('sample-site', 'default-site').import!
    layout.reload
    assert_equal 'default',               layout.identifier
    assert_equal 'Default Layout',        layout.label
    assert_equal "{{cms:text content}}",  layout.content
    assert_equal 'default_css',           layout.css
    assert_equal 'default_js',            layout.js
  end

  def test_export
    host_path = File.join(ComfortableMexicanSofa.config.seeds_path, "test-site")

    layout_1_content_path = File.join(host_path, "layouts/default/content.html")
    layout_2_content_path = File.join(host_path, "layouts/nested/content.html")
    layout_3_content_path = File.join(host_path, "layouts/nested/child/content.html")

    ComfortableMexicanSofa::Seeds::Layout::Exporter.new("default-site", "test-site").export!

    assert File.exist?(layout_1_content_path)
    assert File.exist?(layout_2_content_path)
    assert File.exist?(layout_3_content_path)

    out = <<~TEXT
      [attributes]
      ---
      label: Default Layout
      app_layout:\s
      position: 0

      [content]
      {{cms:text content}}
      [js]
      default_js
      [css]
      default_css
    TEXT
    assert_equal out, IO.read(layout_1_content_path)

    out = <<~TEXT
      [attributes]
      ---
      label: Nested Layout
      app_layout:\s
      position: 0

      [content]
      {{cms:text header}}
      {{cms:text content}}
      [js]
      nested_js
      [css]
      nested_css
    TEXT
    assert_equal out, IO.read(layout_2_content_path)

    out = <<~TEXT
      [attributes]
      ---
      label: Child Layout
      app_layout:\s
      position: 0

      [content]
      {{cms:text left_column}}
      {{cms:text right_column}}
      [js]
      child_js
      [css]
      child_css
    TEXT
    assert_equal out, IO.read(layout_3_content_path)

  ensure
    FileUtils.rm_rf(host_path)
  end
end
