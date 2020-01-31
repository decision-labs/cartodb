module Carto
  class GCloudUserSettings

    REDIS_PREFIX = 'do_settings'

    STORE_ATTRIBUTES = [ :service_account, :bq_public_project,
      :gcp_execution_project, :bq_project, :bq_dataset, :gcs_bucket ]

    attr_reader :service_account, :bq_public_project,
                :gcp_execution_project, :bq_project, :bq_dataset, :gcs_bucket

    def initialize(user, attributes)
      @username = user.username
      @api_key = user.api_key

      h = attributes.symbolize_keys
      @service_account = h[:service_account]
      @bq_public_project = h[:bq_public_project]
      @gcp_execution_project = h[:gcp_execution_project]
      @bq_project = h[:bq_project]
      @bq_dataset = h[:bq_dataset]
      @gcs_bucket = h[:gcs_bucket]
    end

    def store
      $users_metadata.hmset(key, *values.to_a)
    end

    def values
      hash = {}
      STORE_ATTRIBUTES.each { |attr| hash[attr] = self.send(attr) }
      hash
    end

    def remove
      $users_metadata.hset key
    end

    def key
      require 'byebug'; byebug
      "#{REDIS_PREFIX}:#{@username}:#{@api_key}"
    end
  end
end
