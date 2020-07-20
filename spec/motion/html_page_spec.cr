require "../spec_helper"

describe Motion::Base do
  describe "tags that contain contents" do
    it "can be called with various arguments" do
      view(&.header("text")).should eq %(<header>text</header>)
      view(&.header("text", {class: "stuff"})).should eq %(<header class="stuff">text</header>)
      view(&.header("text", class: "stuff")).should eq %(<header class="stuff">text</header>)
    end

    it "dasherizes attribute names" do
      view(&.header("text", data_foo: "stuff")).should eq %(<header data-foo="stuff">text</header>)
    end
  end

  describe "empty tags" do
    it "can be called with various arguments" do
      view(&.br).should eq %(<br>)
      view(&.img(src: "my_src")).should eq %(<img src="my_src">)
      view(&.img({src: "my_src"})).should eq %(<img src="my_src">)
      view(&.img({:src => "my_src"})).should eq %(<img src="my_src">)
    end
  end

  describe "HTML escaping" do
    it "escapes text" do
      UnsafePage.new.render.should eq "&lt;script&gt;not safe&lt;/span&gt;"
    end

    it "escapes HTML attributes" do
      unsafe = "<span>bad news</span>"
      escaped = "&lt;span&gt;bad news&lt;/span&gt;"
      view(&.img(src: unsafe)).should eq %(<img src="#{escaped}">)
      view(&.img({src: unsafe})).should eq %(<img src="#{escaped}">)
      view(&.img({:src => unsafe})).should eq %(<img src="#{escaped}">)
    end
  end

  it "renders complicated HTML syntax" do
    TestRender.new.render.should be_a(String)
  end

  it "can render raw strings" do
    view(&.raw("<safe>")).should eq "<safe>"
  end

  describe "can be used to render layouts" do
    it "renders layouts and needs" do
      InnerPage.new(foo: "bar").render.should contain %(<title>A great title</title>)
      InnerPage.new(foo: "bar").render.should contain %(<body>Inner textbar</body>)
    end
  end

  describe "props with defaults" do
    it "allows default values to needs" do
      LessNeedyDefaultsPage.new.render.should contain %(<div>string default</div>)
    end

    it "allows false as default value to needs" do
      LessNeedyDefaultsPage.new.render.should contain %(<div>bool default</div>)
    end

    it "allows nil as default value to needs" do
      LessNeedyDefaultsPage.new.render.should contain %(<div>nil default</div>)
    end

    it "infers the default value from nilable needs" do
      LessNeedyDefaultsPage.new.render.should contain %(<div>inferred nil default</div>)
    end

    it "infers the default value from nilable needs" do
      LessNeedyDefaultsPage.new.render.should contain %(<div>inferred nil default 2</div>)
    end
  end

  it "accepts extra arguments so pages are more flexible with exposures" do
    InnerPage.new(foo: "bar", ignore_me: true)
  end
end

private def view
  TestRender.new.tap do |page|
    yield page
  end.view.to_s
end