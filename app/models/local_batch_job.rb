class LocalBatchJob < ApplicationRecord
  include ActiveModel::Validations

  extend FriendlyId
  friendly_id :name, use: :slugged

  has_and_belongs_to_many :users
  has_many :local_tweets, dependent: :delete_all
  belongs_to :project
  has_many :results

  validates :name, presence: true, uniqueness: {message: "Name must be unique"}
  validates_presence_of :project
  validates_with CsvValidator, fields: [:job_file]

  enum processing_mode: {default: 0, test: 1}, _suffix: :processing_mode

  attr_accessor :job_file


  def completed_by
    return [] unless status == 'ready'
    completed_by = []
    total_count = local_tweets.may_be_available.count
    users.each do |u|
      user_count = results.counts_by_user(u.id)
      completed_by.push(u.username) if user_count == total_count
    end
    completed_by
  end

  def cleanup
    local_tweets.delete_all
  end

  def status
    return 'processing' if processing
    return 'deleting' if deleting
    return 'empty' if local_tweets.count == 0
    'ready'
  end

  def allows_user?(user_id)
    return false if user_id.nil?
    users.exists?(user_id) ? true : false
  end

  def default_instructions
    "# Instructions for this task"
  end
end
