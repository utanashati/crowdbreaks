class QuestionSequencesController < ApplicationController
  authorize_resource class: false

  def show
    @project = Project.friendly.find(params[:project_id])

    # make sure we are working with the original project
    primary_project = @project.primary_project

    # only allow access if project is both public and accessible by user
    if not primary_project.public?
      redirect_to projects_path unless primary_project.accessible_by?(current_user)
    end

    if primary_project.active_question_sequence_id == 0
      # By default pick project as question sequence (active_question_sequence is initialized as 0)
      question_sequence_project = primary_project
    else
      # Otherwise find project with id
      question_sequence_project = Project.find(primary_project.active_question_sequence_id)
    end

    # Collect question sequence info
    @question_sequence = QuestionSequence.new(question_sequence_project).load
    # Other
    @user_id = current_or_guest_user.id
    @tweet_id = primary_project.get_tweet(user_id: @user_id)

    # @tweet_id = '1047868518224416769'
    # @tweet_id = '564984221203431000'  # invalid tweet
  end

  def create
    result = Result.new(results_params)

    # if captcha is verified save data
    if params.has_key?(:recaptcha_response)
      resp = RecaptchaVerification.new.verify(params[:recaptcha_response])
      if not resp['success']
        render json: { errors: resp['error-codes'].to_a, captcha_verified: false }, status: 400
      else
        if result.save
          render json: { captcha_verified: true }, status: 200
        else
          render json: { errors: ['internal error'], captcha_verified: true }, status: 400
        end
      end
    else
      if result.save
        head :ok
      else
        head :bad_request
      end
    end
  end


  def final
    api = FlaskApi.new
    project = Project.find_by(id: final_params[:project_id])
    user_id = final_params[:user_id]
    tweet_id = final_params[:tweet_id]
    test_mode = final_params[:test_mode]

    if project.nil?
      render json: {}, status: 400 and return
    end

    if test_mode
      new_tweet = project.get_tweet(test_mode: true)
      render json: {tweet_id: new_tweet}, status: 200 and return
    end

    primary_project = project.primary_project

    # update count
    if project.results.count > 0
      project.question_sequences_count = project.results.group(:tweet_id, :user_id).count.length
      project.save
    end

    # update tweet in Redis pool
    if primary_project.stream_annotation_mode?
      api.update_tweet(primary_project.es_index_name, user_id, tweet_id)
    end

    # get next tweet
    new_tweet_id = primary_project.get_tweet(user_id: user_id)

    # save logs
    logs = final_params.fetch(:logs, {})
    unless logs.empty?
      qs_log = QuestionSequenceLog.create(log: logs)
      # associated all previous results with logs
      num_changed = project.results.where({user_id: user_id, tweet_id: tweet_id, question_sequence_log_id: nil, created_at: 1.day.ago..Time.current}).update_all(question_sequence_log_id: qs_log.id)
      if num_changed == 0
        ErrorLogger.error("Could not find any previous results to Question Sequence Log #{qs_log.id}")
      end
    end
    # simply return new tweet ID
    render json: {
      tweet_id: new_tweet_id,
    }, status: 200
  end

  private

  def final_params
    params.require(:qs).permit(:tweet_id, :user_id, :project_id, :test_mode,
                               logs: [:timeInitialized, :delayStart, :delayNextQuestion, :timeMounted, :userTimeInitialized, :totalDurationQuestionSequence, :timeQuestionSequenceEnd,
                                      results: [:submitTime, :timeSinceLastAnswer, :questionId],
                                      resets: [:resetTime, :resetAtQuestionId, previousResultLog: [:submitTime, :timeSinceLastAnswer, :questionId]]])
  end

  def results_params
    params.require(:result).permit(:answer_id, :tweet_id, :question_id, :user_id, :project_id)
  end

end
