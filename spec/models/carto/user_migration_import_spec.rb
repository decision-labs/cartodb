require_relative '../../spec_helper_min'

describe Carto::UserMigrationImport do
  it '#import throws an exception if import_metadata and dry are passed' do
    import = Carto::UserMigrationImport.create(
      exported_file: 'irrelevant_file',
      json_file: "irrelevant_json_file",
      database_host: 'database_host',
      user_id: 'irrelevant_user_id',
      organization_id: 'irrelevant_organization_id',
      import_metadata: true,
      dry: true
    )
    import.run_import.should eq false
    import.state.should eq 'failure'
    import.log.collect_entries.should match(/Dry dry cannot be true while import_metadata is true/)
  end

  it 'fails saving a migration with dry and import_metadata' do
    import = Carto::UserMigrationImport.create(
      exported_file: 'irrelevant_file',
      json_file: "irrelevant_json_file",
      database_host: 'database_host',
      user_id: 'irrelevant_user_id',
      organization_id: 'irrelevant_organization_id',
      import_metadata: true,
      dry: true
    )
    expect { import.save! }.to(
      raise_error(ActiveRecord::RecordInvalid, /dry cannot be true while import_metadata is true/)
    )
  end

  describe '#import' do
    before :each do
      @org = FactoryGirl.create(:organization)
      @org.whitelisted_email_domains = []
      @org.save
      @user = FactoryGirl.create(:valid_user)
      @user.save
      @user = Carto::User.find(@user.id)
      @import = Carto::UserMigrationImport.create(
        exported_file: 'irrelevant_file',
        json_file: "irrelevant_json_file",
        database_host: 'database_host',
        user_id: @user.id,
        organization_id: @org.id,
        import_metadata: true,
        dry: false
      )
      setup_mocks
    end

    it 'updates database host for imported user' do
      should_import_metadata_for_user(@user)
      @import.org_import = false
      @import.organization_id = nil
      should_update_database_host_for_users([@user])

      @import.run_import
    end

    it 'updates database host for all users in org' do
      users = create_and_add_users_to_organizaton
      should_import_metadata_for_organization(@organization_mock)
      allow(@import).to receive(:update_attributes)
      @import.org_import = true
      @import.user_id = nil
      should_update_database_host_for_users(users)

      @import.run_import
    end

    private

    def should_update_database_host_for_users(users)
      sequel_user_mock = Object.new
      allow(::User).to receive(:[]).and_return(sequel_user_mock)
      expect(sequel_user_mock).to receive(:reload).times(users.length)
      users.each do |user|
        expect(user).to receive(:database_host=).with('database_host').once
        expect(user).to receive(:save!).once
      end
    end

    def setup_mocks
      @organization_mock = Carto::Organization.new
      @import.stubs(:assert_organization_does_not_exist)
      @import.stubs(:assert_user_does_not_exist)
      @user_migration_package_mock = Object.new
      allow(Carto::UserMigrationPackage).to receive(:for_import).and_return(@user_migration_package_mock)
      @user_migration_package_mock.stubs(:download).with('irrelevant_file')
      allow(@user_migration_package_mock).to receive(:meta_dir).and_return('irrelevant_meta_dir')
      allow(@user_migration_package_mock).to receive(:data_dir).and_return('irrelevant_data_dir')
      @user_mock = Carto::User.new
      @import_job_mock = Object.new
      allow(@import_job_mock).to receive(:db_exists?).and_return(false)
      @import_job_mock.expects(:run!).once
      @import_job_mock.expects(:terminate_connections).once
      allow(CartoDB::DataMover::ImportJob).to receive(:new).and_return(@import_job_mock)
      @user_migration_package_mock.stubs(:cleanup)
      @import.expects(:save!).once.returns @import
    end

    def expected_job_arguments
      {
        job_uuid: nil,
        file: "irrelevant_data_dir/irrelevant_json_file",
        data: true,
        metadata: false,
        host: :database_host,
        rollback: false,
        into_org_name: nil,
        mode: :import,
        logger: @import.log.logger,
        import_job_logger: @import.log.logger
      }
    end

    def should_import_metadata_for_user(user)
      allow(@user_migration_package_mock).to receive(:meta_dir).and_return('irrelevant_meta_dir')
      expect_any_instance_of(Carto::UserMetadataExportService).to receive(:import_from_directory).with('irrelevant_meta_dir')
                                      .returns user
      expect_any_instance_of(Carto::UserMetadataExportService).to receive(:import_metadata_from_directory)
                                      .with(user, 'irrelevant_meta_dir')
    end

    def should_import_metadata_for_organization(organization)
      allow(@user_migration_package_mock).to receive(:meta_dir).and_return('irrelevant_meta_dir')
      allow_any_instance_of(Carto::OrganizationMetadataExportService).to receive(:import_from_directory).with('irrelevant_meta_dir')
                                              .once.returns organization
      allow_any_instance_of(Carto::OrganizationMetadataExportService).to receive(:import_metadata_from_directory)
                                              .once.with(organization, 'irrelevant_meta_dir')
    end

    def create_and_add_users_to_organizaton
      user2 = Carto::User.new
      user3 = Carto::User.new
      @organization_mock.users << user2
      @organization_mock.users << user3
    end
  end
end
