
require 'typhoeus'
require 'active_support/core_ext/object/to_query'

require 'banner_course'

class PublicSchedule

  #
  # The default URI for the BU Brain public schedule.
  # 
  DEFAULT_URI = 'https://ssb.cc.binghamton.edu/banner'

  #
  # Return each of the banner URI suffixes associated
  # with a given operation.
  # 
  URI_SUFFIXES = {
    :get_course_sessions => 'bwckschd.p_get_crse_unsec'
  }

  #
  # Each of the semester codes, as used by BU Brain.
  #
  SEMESTER_CODE = {
    :fall   => 90,
    :summer => 60,
    :winter => 10,
    :spring => 20
  }

  #
  # This short template is what Banner uses to represent
  # an empty field.
  #
  EMPTY_FIELD = ['dummy', '%']

  #
  # This template contains all of the fields
  # required by Banner's course selection interface.
  #
  COURSE_SELECTION_TEMPLATE = {
      :term_in       => '0',
      :sel_subj      => EMPTY_FIELD,
      :sel_day       => 'dummy',
      :sel_schd      => EMPTY_FIELD,
      :sel_insm      => EMPTY_FIELD,
      :sel_camp      => EMPTY_FIELD,
      :sel_levl      => EMPTY_FIELD,
      :sel_sess      => EMPTY_FIELD,
      :sel_instr     => EMPTY_FIELD,
      :sel_ptrm      => EMPTY_FIELD,
      :sel_attr      => EMPTY_FIELD,
      :sel_crse      => '',
      :sel_title     => '',
      :sel_from_cred => '',
      :sel_to_cred   => '',
      :begin_hh      => '0',
      :begin_mi      => '0',
      :begin_ap      => 'a',
      :end_hh        => '0',
      :end_mi        => '0',
      :end_ap        => 'a'
    }

  def initialize(year=Time.now.year, semester=PublicSchedule.current_session, uri=nil)

    #Record the year and the semester.
    @semester_id = semester_id_for(year, semester)

    #Record the base URI.
    @base_uri = uri || DEFAULT_URI

  end

 
  #
  # Returns all sessions that match the subject code and class number.
  #
  # subject_code: A full subject code for a class name ("EECE 251"), or
  #   a subject-only subject code ("EECE"). If the latter is provided, a
  #   class_number must be provided as well.
  # class_number: The course number ("251"), if not provided in the subject code.
  #
  def get_course_sessions(subject_code, class_number=nil)

    #If only a subject code was provided, try to split it into a course name and class number.
    subject_code, class_number = subject_code.split if class_number.nil?

    #Build the request that will fetch the given course sessions.S
    #This (unfortunate) literal request is required by the Oracle server.
    request = COURSE_SELECTION_TEMPLATE.clone

    #Populate the template fields which are used to retreive courses by number...
    request[:term_in] = @semester_id
    request[:sel_subj] = ['dummy', subject_code]
    request[:sel_crse] = class_number

    #... and fetch the raw course data.
    raw_course_data = perform_banner_request(:get_course_sessions, request).body

    #Convert the raw data to a collection of course objects, and return.
    BannerCourse.collection_from_html(raw_course_data)

  end


  #
  # Quick heuristic to gague the current semster.
  # Should be replaced by a better algorithm.
  # TODO: Replace me!
  #
  def self.current_session
    case Time.now.month
      when (1..5)  then :spring
      when (6..7)  then :summer 
      when (8..12) then :fall
    end
  end


  private

  #
  # Convert the given object into a query string, removing all 
  # pairs of square brackets; as these upset the Oracle server.
  # 
  def convert_to_query(parameters)
    parameters.to_query.gsub("%5B%5D", '')
  end

  #
  # Performs
  #
  def perform_banner_request(target, data={}, referrer='')

    #Compute the URI which we're trying to access.
    target_uri = "#@base_uri/#{URI_SUFFIXES[target]}"

    #Perform the actual request.
    Typhoeus.post(target_uri, body: convert_to_query(data))

  end

  #
  # Returns the banner semester id for the given year/semester combination.
  #
  def semester_id_for(year, semester)
    "#{year}#{SEMESTER_CODE[semester]}"
  end



end
