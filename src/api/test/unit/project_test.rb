require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'json'
#require '/usr/lib64/ruby/gems/1.9.1/gems/perftools.rb-2.0.0/lib/perftools.so'

class ProjectTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects( :home_Iggy )
  end

  def test_flags_to_axml
    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size

    xml_string = @project.to_axml
    #puts xml_string

    #check the results
    assert_xml_tag xml_string, :tag => :project, :children => { :count => 1, :only => { :tag => :build } }
    assert_xml_tag xml_string, :parent => :project, :tag => :build, :children => { :count => 2 }

    assert_xml_tag xml_string, :tag => :project, :children => { :count => 1, :only => { :tag => :publish } }
    assert_xml_tag xml_string, :parent => :project, :tag => :publish, :children => { :count => 2 }

  end


  def test_add_new_flags_from_xml
    User.current = users( :Iggy )

    #precondition check
    @project.flags.delete_all
    @project.reload
    assert_equal 0, @project.flags.size

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <build>
          <disable repository='10.2' arch='i586'/>
        </build>
        <publish>
          <enable repository='10.2' arch='x86_64'/>
        </publish>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
      </project>"
      )

    position = 1
    %w(build publish debuginfo).each do |flagtype|
      position = @project.update_flags(axml, flagtype, position)
    end

    @project.save
    @project.reload

    #check results
    assert_equal 1, @project.type_flags('build').size
    assert_equal 'disable', @project.type_flags('build')[0].status
    assert_equal '10.2', @project.type_flags('build')[0].repo
    assert_equal 'i586', @project.type_flags('build')[0].architecture.name
    assert_equal 1, @project.type_flags('build')[0].position
    assert_nil @project.type_flags('build')[0].package
    assert_equal 'home:Iggy', @project.type_flags('build')[0].project.name

    assert_equal 1, @project.type_flags('publish').size
    assert_equal 'enable', @project.type_flags('publish')[0].status
    assert_equal '10.2', @project.type_flags('publish')[0].repo
    assert_equal 'x86_64', @project.type_flags('publish')[0].architecture.name
    assert_equal 2, @project.type_flags('publish')[0].position
    assert_nil @project.type_flags('publish')[0].package
    assert_equal 'home:Iggy', @project.type_flags('publish')[0].project.name

    assert_equal 1, @project.type_flags('debuginfo').size
    assert_equal 'disable', @project.type_flags('debuginfo')[0].status
    assert_equal '10.0', @project.type_flags('debuginfo')[0].repo
    assert_equal 'i586', @project.type_flags('debuginfo')[0].architecture.name
    assert_equal 3, @project.type_flags('debuginfo')[0].position
    assert_nil @project.type_flags('debuginfo')[0].package
    assert_equal 'home:Iggy', @project.type_flags('debuginfo')[0].project.name

  end


  def test_delete_flags_through_xml
    User.current = users( :Iggy )

    #check precondition
    assert_equal 2, @project.type_flags('build').size
    assert_equal 2, @project.type_flags('publish').size

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
      )

    @project.update_all_flags(axml)
    assert_equal 0, @project.type_flags('build').size
    assert_equal 0, @project.type_flags('publish').size
  end


  def test_store_axml
    User.current = users( :Iggy )

    original = @project.to_axml

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>
        <url></url>
        <disable/>
      </project>"
      )

    @project.update_from_xml!(axml)

    assert_equal 0, @project.type_flags('build').size
    assert_equal 1, @project.type_flags('debuginfo').size

    @project.update_from_xml!(Xmlhash.parse(original))
  end

  def test_ordering
    User.current = users(:Iggy)

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>local</arch>
          <arch>i586</arch>
          <arch>x86_64</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml!(axml)
    @project.reload

    xml = @project.render_xml

    # validate i586 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :after => { :tag => :arch, :content => 'local' }
    assert_xml_tag xml, :tag => :arch, :content => 'i586', :before => { :tag => :arch, :content => 'x86_64' }

    # now verify it's not happening randomly
    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='images'>
          <arch>i586</arch>
          <arch>x86_64</arch>
          <arch>local</arch>
        </repository>
      </project>"
      )
    @project.update_from_xml!(axml)

    xml = @project.render_xml

    # validate x86_64 is in the middle
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :after => { :tag => :arch, :content => 'i586' }
    assert_xml_tag xml, :tag => :arch, :content => 'x86_64', :before => { :tag => :arch, :content => 'local' }

  end

  def test_maintains
    User.current = users(:Iggy)

    #project is given as axml
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }

    # add one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro'/>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro2.0" }

    # remove one maintained project
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <maintenance>
          <maintains project='BaseDistro2.0'/>
        </maintenance>
      </project>"
      )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro" }
    assert_xml_tag xml, :tag => :maintains, :attributes => { :project => "BaseDistro2.0" }
    assert_xml_tag xml, :tag => :maintenance

    # drop entire <maintenance> defs
    axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
      </project>"
      )
    @project.update_from_xml!(axml)
    @project.reload
    xml = @project.render_xml
    assert_no_xml_tag xml, :tag => :maintenance
  end

  test "duplicated repos" do
     User.current = users( :king )
     orig = @project.render_xml

     axml = Xmlhash.parse(
      "<project name='home:Iggy'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <repository name='10.2'>
          <arch>x86_64</arch>
        </repository>
        <repository name='10.2'>
          <arch>i586</arch>
        </repository>
      </project>"
      )
     assert_raise(ActiveRecord::RecordInvalid) do
       Project.transaction do
         @project.update_from_xml!(axml)
       end
     end
     @project.reload
     assert_equal orig, @project.render_xml
  end

  test "duplicated repos with remote" do
     User.current = users( :Iggy )
     orig = @project.render_xml

     xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
  </repository>
</project>
END
     axml = Xmlhash.parse(xml)
     assert_raise(ActiveRecord::RecordInvalid) do
       Project.transaction do
         @project.update_from_xml!(axml)
       end
     end
     @project.reload
     assert_equal orig, @project.render_xml
  end

  test "not duplicated repos with remote" do
     User.current = users( :Iggy )
     xml = <<END
<project name="home:Iggy">
  <title>Iggy"s Home Project</title>
  <description>dummy</description>
  <repository name="remote_2">
    <path project="RemoteInstance:remote_project_2" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
  <repository name="remote_1">
    <path project="RemoteInstance:remote_project_1" repository="standard"/>
    <arch>x86_64</arch>
    <arch>i586</arch>
  </repository>
</project>
END
     axml = Xmlhash.parse(xml)
     Project.transaction do
       @project.update_from_xml!(axml)
     end
     @project.reload
     assert_equal xml, @project.render_xml
  end

  def test_handle_project_links
    User.current = users( :Iggy )

    # project A
    axml = Xmlhash.parse(
      "<project name='home:Iggy:A'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy' />
      </project>"
      )
    projectA = Project.create( :name => "home:Iggy:A" )
    projectA.update_from_xml!(axml)
    # project B
    axml = Xmlhash.parse(
      "<project name='home:Iggy:B'>
        <title>Iggy's Home Project</title>
        <description>dummy</description>
        <link project='home:Iggy:A' />
      </project>"
      )
    projectB = Project.create( :name => "home:Iggy:B" )
    projectB.update_from_xml!(axml)

    # validate xml
    xml_string = projectA.to_axml
    assert_xml_tag xml_string, :tag => :link, :attributes => { :project => "home:Iggy" }
    xml_string = projectB.to_axml
    assert_xml_tag xml_string, :tag => :link, :attributes => { :project => "home:Iggy:A" }

    projectA.destroy
    projectB.reload
    xml_string = projectB.to_axml
    assert_no_xml_tag xml_string, :tag => :link
  end


  def test_repository_with_download_url
    User.current = users( :king )

    prj = Project.new(name: "DoD")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='DoD'>
        <title/>
        <description/>
        <repository name='standard'>
          <download arch='i586' url='http://me.org' repotype='rpmmd'>
           <archfilter>i686,i586,noarch</archfilter>
           <master url='http://download.opensuse.org' sslfingerprint='0815' />
           <pubkey>grfzl</pubkey>
          </download>
          <arch>i586</arch>
        </repository>
      </project>"
      )
    )

    xml = prj.to_axml
    assert_xml_tag xml, :tag => :download, :attributes => {arch: "i586", url: "http://me.org", repotype: "rpmmd"}
    assert_xml_tag xml, :tag => :archfilter, :content => "i686,i586,noarch"
    assert_xml_tag xml, :tag => :master, :attributes => {url: "http://download.opensuse.org", sslfingerprint: "0815"}
    assert_xml_tag xml, :tag => :pubkey, :content => "grfzl"
  end

  def test_repository_path_sync
    User.current = users( :king )

    prj = Project.new(name: "Enterprise-SP0:GA")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='Enterprise-SP0:GA'>
        <title/>
        <description/>
        <repository name='sp0_ga' />
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP0:Update")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='Enterprise-SP0:Update' kind='maintenance_release'>
        <title/>
        <description/>
        <repository name='sp0_update' >
          <path project='Enterprise-SP0:GA' repository='sp0_ga' />
        </repository>
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP1:GA")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='Enterprise-SP1:GA'>
        <title/>
        <description/>
        <repository name='sp1_ga' >
          <path project='Enterprise-SP0:GA' repository='sp0_ga' />
        </repository>
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP1:Update")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='Enterprise-SP1:Update' kind='maintenance_release'>
        <title/>
        <description/>
        <repository name='sp1_update' >
          <path project='Enterprise-SP1:GA' repository='sp1_ga' />
          <path project='Enterprise-SP0:Update' repository='sp0_update' />
        </repository>
      </project>"
      )
    )
    prj = Project.new(name: "Enterprise-SP1:Channel:Server")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='Enterprise-SP1:Channel:Server'>
        <title/>
        <description/>
        <repository name='channel' >
          <path project='Enterprise-SP1:Update' repository='sp1_update' />
        </repository>
      </project>"
      )
    )
    # this is what the classic add_repository call is producing:
    prj = Project.new(name: "My:Branch")
    prj.update_from_xml!( Xmlhash.parse(
      "<project name='My:Branch'>
        <title/>
        <description/>
        <repository name='Channel_Server' >
          <path project='Enterprise-SP1:Channel:Server' repository='channel' />
        </repository>
        <repository name='my_branch_sp0_update' >
          <path project='Enterprise-SP0:Update' repository='sp0_update' />
        </repository>
        <repository name='my_branch_sp1_update' >
          <path project='Enterprise-SP1:Update' repository='sp1_update' />
        </repository>
      </project>"
      )
    )
    # however, this is not correct, because my:branch (or an incident)
    # is providing in this situation often a package in SP0:Update which
    # must be used for building the package in sp1 repo.
    # Since the order of adding the repositories is not fixed or can even
    # be extended with later calls, we need to sync this always after finishing a
    # a setup of new branched packages with this sync function:
    xml = prj.to_axml
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp1_update"},
                        :children => { count: 1, :only => { :tag => :path } }

    assert_no_xml_tag xml, :tag => :path, :attributes => { project: "My:Branch", repository: "my_branch_sp0_update" }
    prj.sync_repository_pathes
    xml = prj.to_axml
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp1_update"},
                        :children => { count: 2, :only => { :tag => :path } }
    assert_xml_tag xml, :tag => :path, :attributes => { project: "My:Branch", repository: "my_branch_sp0_update" }
    # untouched
    assert_xml_tag xml, :tag => :repository, :attributes => {name: "my_branch_sp0_update"},
                        :children => { count: 1, :only => { :tag => :path } }
    assert_xml_tag xml, :parent => { :tag => :repository, :attributes => {name: "Channel_Server"} },
                        :tag => :path, :attributes => {project: "Enterprise-SP1:Channel:Server", repository: "channel"}

    # must not change again anything
    prj.sync_repository_pathes
    assert_equal xml, prj.to_axml
  end

  #helper
  def put_flags(flags)
    flags.each do |flag|
      if flag.architecture.nil?
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture} \t #{flag.repo} \t #{flag.position}"
      else
        puts "#{flag} \t #{flag.id} \t #{flag.status} \t #{flag.architecture.name} \t #{flag.repo} \t #{flag.position}"
      end
    end
  end

  test 'invalid names' do
    # no ::
    assert !Project.valid_name?('home:M0ses:raspi::qtdesktop')
    assert !Project.valid_name?(10)
    assert !Project.valid_name?('')
    assert !Project.valid_name?('_foobar')
    assert !Project.valid_name?("4" * 250)
  end

  test 'valid name' do
    assert Project.valid_name?("foobar")
    assert Project.valid_name?("Foobar_")
    assert Project.valid_name?("foo1234")
    assert Project.valid_name?("4" * 200)
  end

  def test_cycle_handling
    User.current = users( :king )

    prj_a = Project.new(name: "Project:A")
    prj_a.update_from_xml!( Xmlhash.parse(
      "<project name='Project:A'>
        <title/>
        <description/>
       </project>") )
    prj_a.save!
    prj_b = Project.new(name: "Project:B")
    prj_b.update_from_xml!( Xmlhash.parse(
      "<project name='Project:B'>
        <title/>
        <description/>
        <link project='Project:A'/>
       </project>") )
    prj_b.save!
    prj_a.update_from_xml!( Xmlhash.parse(
      "<project name='Project:A'>
        <title/>
        <description/>
        <link project='Project:B'/>
       </project>") )
    prj_a.save!

    assert_equal [], prj_a.expand_all_packages
    assert_equal 2,  prj_a.expand_all_projects.length
  end

  test 'exists_by_name' do
    User.current = users( :Iggy )

    assert Project.exists_by_name('home:Iggy')
    assert Project.exists_by_name('RemoteInstance')
    assert Project.exists_by_name('RemoteInstance:NoMatterIfThisProjectExistsOrNot')
    assert Project.exists_by_name('RemoteInstance:NoMatter:IfThisProjectExistsOrNot')
    assert_not Project.exists_by_name('NonExistingProject')
    assert_not Project.exists_by_name('Some:NonExistingProject')
    assert_not Project.exists_by_name('HiddenProject')
    assert_not Project.exists_by_name('HiddenRemoteInstance')
  end

  test 'validate_maintenance_xml_attribute returns an error if User can not modify target project' do
    User.current = users(:tom)
    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <maintenance><maintains project="Apache"></maintains></maintenance>
      </project>
    XML

    actual = Project.validate_maintenance_xml_attribute(Xmlhash.parse(xml))
    expected = { error: "No write access to maintained project Apache" }
    assert_equal actual, expected
  end

  test 'validate_maintenance_xml_attribute returns no error if User can modify target project' do
    User.current = users(:king)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <maintenance><maintains project="Apache"></maintains></maintenance>
      </project>
    XML

    actual = Project.validate_maintenance_xml_attribute(Xmlhash.parse(xml))
    assert_equal actual, {}
  end

  test 'validate_link_xml_attribute returns no error if target project is not disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <link project="Apache"></link>
      </project>
    XML

    actual = Project.validate_link_xml_attribute(Xmlhash.parse(xml), project.name)
    assert_equal actual, {}
  end

  test 'validate_link_xml_attribute returns an error if target project access is disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)

    xml = <<-XML.strip_heredoc
      <project name="the_project">
        <title>Up-to-date project</title>
        <description>the description</description>
        <link project="home:Iggy"></link>
      </project>
    XML

    flag = project.add_flag('access', 'disable')
    flag.save

    actual = Project.validate_link_xml_attribute(Xmlhash.parse(xml), 'the_project')
    expected = { error: "Project links work only when both projects have same read access protection level: the_project -> home:Iggy" }
    assert_equal actual, expected
  end

  test 'validate_repository_xml_attribute returns no error if project access is not disabled' do
    User.current = users(:Iggy)

    xml = <<-XML.strip_heredoc
      <project name='other_project'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'other_project')
    expected = {}
    assert_equal actual, expected
  end

  test 'returns an error if repository access is disabled' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    flag = project.add_flag('access', 'disable')
    flag.save

    xml = <<-XML.strip_heredoc
      <project name='other_project'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'other_project')
    expected = { error: "The current backend implementation is not using binaries from read access protected projects home:Iggy" }
    assert_equal actual, expected
  end

  test 'returns no error if target project equals project' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    flag = project.add_flag('access', 'disable')
    flag.save

    xml = <<-XML.strip_heredoc
      <project name='home:Iggy'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><path project='home:Iggy'></path></repository>
      </project>
    XML

    actual = Project.validate_repository_xml_attribute(Xmlhash.parse(xml), 'home:Iggy')
    expected = { }
    assert_equal actual, expected
  end

  test 'get_removed_repositories returns all repositories if new_repositories does not contain the old repositories' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>First</name></repository>
        <repository><name>Second</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, project.repositories.to_a
  end

  test 'get_removed_repositories returns the repository if new_repositories does not include it' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
          <title>Up-to-date project</title>
          <description>the description</description>
          <repository><name>10.2</name></repository>
          <repository><name>First</name></repository>
        </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, [repositories(:repositories_96)]
  end

  test 'get_removed_repositories returns no repository if new_repositories matches old_repositories' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>10.2</name></repository>
        <repository><name>repo</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, []
  end

  test 'get_removed_repositories returns all repositories if new_repositories is empty' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories << repositories(:repositories_96)

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, project.repositories.to_a
  end

  test 'get_removed_repositories returns nothing if repositories is empty' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    project.repositories.destroy_all

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        <repository><name>First</name></repository>
        <repository><name>Second</name></repository>
      </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, []
  end

  test 'get_removed_repositories does not include repositories which belong to a remote project' do
    User.current = users(:Iggy)
    project = projects(:home_Iggy)
    first_repository = project.repositories.first

    repository = repositories(:repositories_96)
    repository.remote_project_name = "my_remote_repository"
    repository.save
    project.repositories << repository

    xml = <<-XML.strip_heredoc
      <project name='#{@project.name}'>
        <title>Up-to-date project</title>
        <description>the description</description>
        </project>
    XML

    actual = project.get_removed_repositories(Xmlhash.parse(xml))
    assert_equal actual, [first_repository]
  end

  test 'check repositories returns no error if no linking and no linking taget repository exists' do
    User.current = users(:Iggy)
    actual = Project.check_repositories(@project.repositories)
    assert_equal actual, {}
  end

  test 'check repositories returns an error if a linking repository exists' do
    User.current = users(:Iggy)

    path = path_elements(:record_0)
    repository = @project.repositories.first
    repository.links << path

    actual = Project.check_repositories(@project.repositories)
    expected = {
        error: "Unable to delete repository; following repositories depend on this project:\nhome:tom/home_coolo_standard"
    }

    assert_equal actual, expected
  end

  test 'check repositories returns an error if a linking target repository exists' do
    User.current = users(:Iggy)

    release_target = release_targets(:release_targets_913785863)
    repository = @project.repositories.first
    repository.targetlinks << release_target

    actual = Project.check_repositories(@project.repositories)
    expected = {
        error: "Unable to delete repository; following target repositories depend on this project:\nhome:Iggy/10.2"
    }

    assert_equal actual, expected
  end

  test 'linked_packages returns all packages from projects inherited by one level' do
    child = projects('BaseDistro2.0_LinkedUpdateProject')

    assert_equal child.packages_from_linked_projects, [['pack2', 'BaseDistro2.0'], ['pack2.linked', 'BaseDistro2.0']]
  end

  test 'linked_packages returns all packages from projects inherited by two levels' do
    CONFIG['global_write_through'] = false
    parent2 = projects('BaseDistro2.0')
    parent1 = projects('BaseDistro2.0_LinkedUpdateProject')
    child = projects('Apache')

    child.linkedprojects.create(project: child,
                               linked_db_project_id: parent1.id,
                               position: 1)

    child.linkedprojects.create(project: child,
                                linked_db_project_id: parent2.id,
                                position: 2)

    result =  parent1.packages + parent2.packages
    result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

    assert_equal child.packages_from_linked_projects, result
    CONFIG['global_write_through'] = true
  end

  test 'linked_packages does not return packages overwritten by the actual project' do
    CONFIG['global_write_through'] = false
    parent = projects('BaseDistro2.0')
    child = projects('BaseDistro2.0_LinkedUpdateProject')

    pack2 = parent.packages.where(name: 'pack2').first
    child.packages << pack2.dup

    assert_equal child.packages_from_linked_projects, [['pack2.linked', 'BaseDistro2.0']]
    CONFIG['global_write_through'] = true
  end

  test 'linked_packages does not return packages overwritten by the actual project inherited from two levels' do
    CONFIG['global_write_through'] = false
    parent2 = projects('BaseDistro2.0')
    parent1 = projects('BaseDistro2.0_LinkedUpdateProject')
    child = projects('Apache')

    child.linkedprojects.create(project: child,
                                linked_db_project_id: parent1.id,
                                position: 1)

    child.linkedprojects.create(project: child,
                                linked_db_project_id: parent2.id,
                                position: 2)

    pack2 = parent2.packages.where(name: 'pack2').first
    child.packages << pack2.dup

    result = parent1.packages + parent2.packages.where(name: 'pack2.linked')
    result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

    assert_equal child.packages_from_linked_projects, result
    CONFIG['global_write_through'] = true
  end

  test 'linked_packages returns overwritten packages from the project with the highest position' do
    CONFIG['global_write_through'] = false
    base_distro = projects('BaseDistro2.0')
    base_distro_update = projects('BaseDistro2.0_LinkedUpdateProject')

    child = projects('Apache')

    child.linkedprojects.create(project: child,
                                linked_db_project_id: base_distro_update.id,
                                position: 1)

    child.linkedprojects.create(project: child,
                                linked_db_project_id: base_distro.id,
                                position: 2)

    pack2 = base_distro.packages.where(name: 'pack2').first
    base_distro_update.packages << pack2.dup

    result = base_distro_update.packages + base_distro.packages.where(name: 'pack2.linked')
    result.sort! { |a, b| a.name.downcase <=> b.name.downcase }.map! { |package| [package.name, package.project.name] }

    assert_equal child.packages_from_linked_projects, result
    CONFIG['global_write_through'] = true
  end
end
