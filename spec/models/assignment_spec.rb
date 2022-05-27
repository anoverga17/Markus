describe Assignment do
  describe 'ActiveRecord associations' do
    it { is_expected.to have_one(:submission_rule).dependent(:destroy) }
    it { is_expected.to validate_presence_of(:submission_rule) }
    it { is_expected.to have_many(:annotation_categories).dependent(:destroy) }
    it { is_expected.to have_many(:groupings) }
    it { is_expected.to have_many(:ta_memberships).through(:groupings) }
    it { is_expected.to have_many(:student_memberships).through(:groupings) }
    it { is_expected.to have_many(:submissions).through(:groupings) }
    it { is_expected.to have_many(:groups).through(:groupings) }
    it { is_expected.to have_many(:notes).dependent(:destroy) }
    it { is_expected.to have_many(:assessment_section_properties) }
    it { is_expected.to accept_nested_attributes_for(:assessment_section_properties) }
    it { is_expected.to have_many(:criteria).dependent(:destroy).order(:position) }
    it { is_expected.to have_many(:peer_criteria).order(:position) }
    it { is_expected.to have_many(:ta_criteria).order(:position) }
    it { is_expected.to have_many(:assignment_files).dependent(:destroy) }
    it { is_expected.to have_many(:test_groups).dependent(:destroy) }
    it { is_expected.to belong_to(:course) }

    it do
      is_expected.to accept_nested_attributes_for(:assignment_files).allow_destroy(true)
    end

    it do
      is_expected.to have_many(:criterion_ta_associations).dependent(:destroy)
    end
    it do
      is_expected.to accept_nested_attributes_for(:submission_rule).allow_destroy(true)
    end
  end

  describe 'ActiveModel validations' do
    it { is_expected.to validate_presence_of(:short_identifier) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:due_date) }
    it { is_expected.to belong_to(:parent_assignment).class_name('Assignment').optional }
    it { is_expected.to have_one(:pr_assignment).class_name('Assignment') }

    describe 'Validation of basic infos of an assignment' do
      let(:assignment) { :assignment }

      before :each do
        @assignment = create(:assignment)
      end

      it 'should create a valid assignment' do
        expect(@assignment).to be_valid
      end

      it 'should require case sensitive unique value for short_identifier' do
        expect(@assignment).to validate_uniqueness_of(:short_identifier).scoped_to(:course_id)
      end
      it 'should have a nil parent_assignment by default' do
        expect(@assignment.parent_assignment).to be_nil
      end
      it 'should have a nil peer_review by default' do
        expect(@assignment.pr_assignment).to be_nil
      end
      it 'should not be a peer review if there is no parent_assessment_id' do
        expect(@assignment.parent_assessment_id).to be_nil
        expect(@assignment.is_peer_review?).to be false
      end
    end

    it 'should catch an invalid date' do
      assignment = create(:assignment, due_date: '2020/02/31')  # 31st day of february
      expect(assignment.due_date).not_to eq '2020/02/31'
    end
    it 'should be a peer review if it has a parent_assessment_id' do
      parent_assignment = create(:assignment)
      assignment = create(:assignment, parent_assignment: parent_assignment)
      expect(assignment.is_peer_review?).to be true
      expect(parent_assignment.is_peer_review?).to be false
    end
    it 'should give a true has_peer_review_assignment result if it does' do
      parent_assignment = create(:assignment)
      assignment = create(:assignment, parent_assignment: parent_assignment)
      expect(parent_assignment.has_peer_review_assignment?).to be true
      expect(assignment.has_peer_review_assignment?).to be false
    end
    it 'should find children assignments when they reference the parent' do
      parent_assignment = create(:assignment)
      assignment = create(:assignment, parent_assignment: parent_assignment)
      expect(parent_assignment.pr_assignment.id).to be assignment.id
      expect(assignment.parent_assignment.id).to be parent_assignment.id
    end
    it 'should not allow the short_identifier to be updated' do
      assignment = create(:assignment)
      assignment.short_identifier = assignment.short_identifier + 'something'
      expect(assignment).not_to be_valid
    end
    it 'should not allow the repository_folder to be updated' do
      assignment = create(:assignment)
      assignment.repository_folder = assignment.repository_folder + 'something'
      expect(assignment).not_to be_valid
    end
  end

  describe 'peer review assignment' do
    it 'should not allow the parent and pr assignments to be from different courses' do
      courses = create_list :course, 2
      a = build(:assignment, course: courses.first, parent_assignment: build(:assignment, course: courses.second))
      expect(a).not_to be_valid
    end

    it 'updates its parent assignment\'s has_peer_review attribute when created' do
      assignment = create(:assignment)
      create(:assignment, course: assignment.course, parent_assignment: assignment)

      expect(assignment.has_peer_review).to eq true
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for required files (assignment_files)' do
      course = create :course
      attrs = {
        course_id: course.id,
        short_identifier: 't',
        description: 't',
        due_date: 1.hour.from_now,
        assignment_files_attributes: [
          { filename: 't.py' }
        ]
      }
      a = Assignment.new(attrs)
      a.repository_folder = 't'
      a.save!

      expect(a.assignment_files.first.filename).to eq 't.py'
    end
  end

  describe '#clone_groupings_from' do
    it 'makes an attempt to update repository permissions when cloning groupings' do
      a1 = create(:assignment, assignment_properties_attributes: { vcs_submit: true })
      a2 = create(:assignment, course: a1.course, assignment_properties_attributes: { vcs_submit: true })
      create :grouping_with_inviter, assignment: a2
      expect(Repository.get_class).to receive(:update_permissions_after)
      a1.clone_groupings_from(a2.id)
    end
  end

  describe '#tas' do
    before :each do
      @assignment = create(:assignment)
    end

    context 'when no TAs have been assigned' do
      it 'returns an empty array' do
        expect(@assignment.tas).to eq []
      end
    end

    context 'when TA(s) have been assigned to an assignment' do
      before :each do
        @grouping = create(:grouping, assignment: @assignment)
        @ta = create(:ta)
        @ta_membership = create(:ta_membership, role: @ta, grouping: @grouping)
      end

      describe 'one TA' do
        it 'returns the TA' do
          expect(@assignment.tas).to eq [@ta]
        end

        context 'when no criteria are found' do
          it 'returns an empty list of criteria' do
            expect(@assignment.criteria).to be_empty
          end

          context 'a submission and result are created' do
            before do
              @submission = create(:submission, grouping: @grouping)
              @result = create(:incomplete_result, submission: @submission)
            end

            it 'has no marks' do
              expect(@result.marks.length).to eq(0)
            end

            it 'gets a subtotal' do
              expect(@result.get_subtotal).to eq(0)
            end
          end
        end

        context 'when rubric criteria are found' do
          before do
            @ta_criteria = Array.new(2) { create(:rubric_criterion, assignment: @assignment) }
            @peer_criteria = Array.new(2) do
              create(:rubric_criterion,
                     assignment: @assignment,
                     ta_visible: false,
                     peer_visible: true)
            end
            @ta_and_peer_criteria = Array.new(2) do
              create(:rubric_criterion,
                     assignment: @assignment,
                     peer_visible: true)
            end
          end

          it 'shows the criteria visible to tas only' do
            expect(@assignment.ta_criteria.ids).to match_array(@ta_criteria.map(&:id) +
                                                               @ta_and_peer_criteria.map(&:id))
          end

          context 'a submission and a result are created' do
            before do
              @submission = create(:submission, grouping: @grouping)
              @result = create(:incomplete_result, submission: @submission)
            end

            it 'creates marks for visible criteria only' do
              expect(@result.marks.length).to eq(4)
            end

            context 'when marks are entered' do
              before do
                result_mark = @result.marks.first
                result_mark.mark = 2.0
                result_mark.save
              end

              it 'gets a subtotal' do
                expect(@result.get_subtotal).to eq(2)
              end

              it 'gets a relative max_mark' do
                expect(@assignment.max_mark).to eq(16)
              end
            end
          end
        end
      end

      describe 'more than one TA' do
        before :each do
          @other_ta = create(:ta)
          @ta_membership =
            create(:ta_membership, role: @other_ta, grouping: @grouping)
        end

        it 'returns all TAs' do
          expect(@assignment.tas).to match_array [@ta, @other_ta]
        end
      end
    end
  end

  describe '#group_assignment?' do
    context 'when invalid_override is allowed' do
      let(:assignment) { build(:assignment, assignment_properties_attributes: { invalid_override: true }) }

      it 'returns true' do
        expect(assignment.group_assignment?).to be true
      end
    end

    context 'when invalid_override is not allowed ' do
      context 'and group_max is greater than 1' do
        let(:assignment) do
          build(:assignment, assignment_properties_attributes: { group_max: 2 })
        end

        it 'returns true' do
          expect(assignment.group_assignment?).to be true
        end
      end

      context 'and group_max is 1' do
        let(:assignment) do
          build(:assignment)
        end

        it 'returns false' do
          expect(assignment.group_assignment?).to be false
        end
      end
    end
  end

  describe '#add_group' do
    context 'when the group name is autogenerated' do
      before :each do
        @assignment = create(:assignment) # Default 'group_name_autogenerated' is true
      end

      it 'adds a group and returns the new grouping' do
        expect(@assignment.add_group).to be_a Grouping
        expect(Group.count).to eq 1
      end
    end

    context 'when the the group name is not autogenerated' do
      before :each do
        @assignment = create(:assignment,
                             assignment_properties_attributes: { group_name_autogenerated: false })
        @group_name = 'a_group_name'
      end

      it 'adds a group with the given name and returns the new grouping' do
        grouping = @assignment.add_group(@group_name)
        group = @assignment.groups.where(group_name: @group_name).first

        expect(grouping).to be_a Grouping
        expect(group).to be_a Group
      end

      context 'and a group with the same name exists' do
        before :each do
          @group = create(:group, group_name: @group_name, course: @assignment.course)
        end

        context 'for this assignment' do
          before :each do
            create(:grouping, assignment: @assignment, group: @group)
          end

          it 'raises an exception' do
            expect { @assignment.add_group(@group_name) }.to raise_error(RuntimeError)
          end
        end

        context 'for another assignment' do
          before :each do
            create(:grouping, group: @group)
          end

          it 'adds the group and returns the new grouping' do
            grouping = @assignment.add_group(@group_name)
            group = @assignment.groups.where(group_name: @group_name).first

            expect(grouping).to be_a Grouping
            expect(group).to be_a Group
          end
        end
      end
    end
  end

  describe '#valid_groupings and #invalid_groupings' do
    before :each do
      @assignment = create(:assignment)
      @groupings = Array.new(2) { create(:grouping, assignment: @assignment) }
    end

    context 'when no groups are valid' do
      it '#valid_groupings returns an empty array' do
        expect(@assignment.valid_groupings).to eq []
      end

      it '#invalid_groupings returns all groupings' do
        expect(@assignment.invalid_groupings).to match_array(@groupings)
      end
    end

    context 'when one group is valid' do
      context 'due to instructor_approval' do
        before :each do
          @groupings.first.update_attribute(:instructor_approved, true)
        end

        it '#valid_groupings returns the valid group' do
          expect(@assignment.valid_groupings).to eq [@groupings.first]
        end

        it '#invalid_groupings returns other, invalid groups' do
          expect(@assignment.invalid_groupings)
            .to match_array(@groupings.drop(1))
        end
      end

      context 'due to meeting min size requirement' do
        before :each do
          create(:accepted_student_membership, grouping: @groupings.first)
        end

        it '#valid_groupings returns the valid group' do
          expect(@assignment.valid_groupings).to eq [@groupings.first]
        end

        it '#invalid_groupings returns other, invalid groups' do
          expect(@assignment.invalid_groupings)
            .to match_array(@groupings.drop(1))
        end
      end
    end

    context 'when all groups are valid' do
      before :each do
        @groupings.each do |grouping|
          create(:accepted_student_membership, grouping: grouping)
        end
      end

      it '#valid_groupings returns all groupings' do
        expect(@assignment.valid_groupings).to match_array(@groupings)
      end

      it '#invalid_groupings returns an empty array' do
        expect(@assignment.invalid_groupings).to eq []
      end
    end
  end

  describe '#grouped_students' do
    before :each do
      @assignment = create(:assignment)
      @grouping = create(:grouping, assignment: @assignment)
    end

    context 'when no students are grouped' do
      it 'returns an empty array' do
        expect(@assignment.grouped_students).to eq []
      end
    end

    context 'when students are grouped' do
      before :each do
        @student = create(:student)
        @membership = create(:accepted_student_membership,
                             role: @student,
                             grouping: @grouping)
      end

      describe 'one student' do
        it 'returns the student' do
          expect(@assignment.grouped_students).to eq [@student]
        end
      end

      describe 'more than one student' do
        before :each do
          @other_student = create(:student)
          @other_membership = create(:accepted_student_membership, role: @other_student, grouping: @grouping)
        end

        it 'returns the students' do
          expect(@assignment.grouped_students)
            .to match_array [@student, @other_student]
        end
      end
    end
  end

  describe '#ungrouped_students' do
    before :each do
      @assignment = create(:assignment)
      @grouping = create(:grouping, assignment: @assignment)
      @students = Array.new(2) { create(:student) }
    end

    context 'when all students are ungrouped' do
      it 'returns all of the students' do
        expect(@assignment.ungrouped_students).to match_array(@students)
      end
    end

    context 'when no students are ungrouped' do
      before :each do
        @students.each do |student|
          create(:accepted_student_membership, role: student, grouping: @grouping)
        end
      end

      it 'returns an empty array' do
        expect(@assignment.ungrouped_students).to eq []
      end
    end
  end

  describe '#assigned_groupings and #unassigned_groupings' do
    before :each do
      @assignment = create(:assignment)
    end

    context 'when there are no groupings' do
      it '#assigned_groupings and #unassigned_groupings returns no groupings' do
        expect(@assignment.assigned_groupings).to eq []
        expect(@assignment.unassigned_groupings).to eq []
      end
    end

    context 'when there are multiple groupings' do
      before :each do
        @groupings = Array.new(2) { create(:grouping, assignment: @assignment) }
      end

      context 'and no TAs have been assigned' do
        it '#assigned_groupings returns no groupings' do
          expect(@assignment.assigned_groupings).to eq []
        end

        it '#unassigned_groupings returns all groupings' do
          expect(@assignment.unassigned_groupings).to match_array(@groupings)
        end
      end

      context 'and multiple TAs are assigned to one grouping' do
        before :each do
          2.times do
            create(:ta_membership, grouping: @groupings[0], role: create(:ta))
          end
        end

        it '#assigned_groupings returns that grouping' do
          expect(@assignment.assigned_groupings).to eq [@groupings.first]
        end

        it '#unassigned_groupings returns the other groupings' do
          expect(@assignment.unassigned_groupings)
            .to match_array(@groupings.drop(1))
        end
      end

      context 'and all groupings have a TA assigned' do
        before :each do
          @groupings.each do |grouping|
            create(:ta_membership, grouping: grouping, role: create(:ta))
          end
        end

        it '#assigned_groupings returns all groupings' do
          expect(@assignment.assigned_groupings).to match_array(@groupings)
        end

        it '#unassigned_groupings returns no groupings' do
          expect(@assignment.unassigned_groupings).to eq []
        end
      end
    end
  end

  context 'A past due assignment with No Late submission rule' do
    context 'without sections' do
      before(:each) do
        @assignment = create(:assignment, due_date: 2.days.ago)
      end

      it 'return the last due date' do
        expect(@assignment.latest_due_date.day).to eq(2.days.ago.day)
      end

      it 'return true on past_collection_date? call' do
        expect(@assignment.past_collection_date?).to be_truthy
      end
    end

    context 'with a section' do
      before(:each) do
        @assignment = create(:assignment,
                             due_date: 2.days.ago,
                             assignment_properties_attributes: { section_due_dates_type: true })
        @section = create(:section, name: 'section_name')
        create(:assessment_section_properties, section: @section, assessment: @assignment, due_date: 1.day.from_now)
      end

      it 'returns the correct due date for the section' do
        expect(@assignment.section_due_date(@section)).to eq(
          @section.assessment_section_properties.find_by(assessment_id: @assignment.id).due_date
        )
      end

      context 'and with another section' do
        before(:each) do
          @section2 = create(:section, name: 'section_name2')
          create(:assessment_section_properties, section: @section2, assessment: @assignment, due_date: 2.days.from_now)
        end

        it 'returns the correct due date for each section' do
          expect(@assignment.section_due_date(@section)).to eq(
            @section.assessment_section_properties.find_by(assessment_id: @assignment.id).due_date
          )
          expect(@assignment.section_due_date(@section2)).to eq(
            @section2.assessment_section_properties.find_by(assessment_id: @assignment.id).due_date
          )
        end
      end
    end
  end

  context 'A before due assignment with No Late submission rule' do
    before(:each) do
      @assignment = create(:assignment, due_date: 2.days.from_now)
    end

    it 'return false on past_collection_date? call' do
      expect !@assignment.past_collection_date?
    end
  end

  describe '#past_remark_due_date?' do
    context 'before the remark due date' do
      let(:assignment) { build(:assignment, assignment_properties_attributes: { remark_due_date: 1.day.from_now }) }

      it 'returns false' do
        expect(assignment.past_remark_due_date?).to be false
      end
    end

    context 'after the remark due date' do
      let(:assignment) { build(:assignment, assignment_properties_attributes: { remark_due_date: 1.day.ago }) }

      it 'returns true' do
        expect(assignment.past_remark_due_date?).to be true
      end
    end
  end

  context 'An Assignment' do
    let(:assignment) { create :assignment }
    before :each do
      @assignment = create(:assignment,
                           assignment_properties_attributes: {
                             group_name_autogenerated: false,
                             group_max: 2
                           })
    end

    context 'as a noteable' do
      it 'display for note without seeing an exception' do
        assignment = create(:assignment)
        assignment.display_for_note
      end
    end

    context 'with a student in a group with a marked submission' do
      before :each do
        @membership = create(:student_membership,
                             grouping: create(:grouping, assignment: @assignment),
                             membership_status: StudentMembership::STATUSES[:accepted])
        sub = create(:submission, grouping: @membership.grouping)
        @result = sub.get_latest_result

        @sum = 0
        [2, 2.7, 2.2, 2].each do |weight|
          rubric_criterion = create(:rubric_criterion, assignment: @assignment, max_mark: weight * 4)
          create(:mark,
                 mark: 4,
                 result: @result,
                 criterion: rubric_criterion)
          @sum += weight
        end
        @total = @sum * 4
      end

      it 'return the correct maximum mark for rubric criteria' do
        expect(@total).to eq @assignment.max_mark
      end

      it 'return the correct group for a given student' do
        expect(@membership.grouping.group).to eq(@assignment.group_by(@membership.role).group)
      end
    end

    context 'with some groupings with students and TAs assigned' do
      before :each do
        5.times do
          grouping = create(:grouping, assignment: @assignment)
          3.times do
            create(:student_membership,
                   grouping: grouping,
                   membership_status: StudentMembership::STATUSES[:accepted])
          end
          create(:ta_membership,
                 grouping: grouping,
                 membership_status: StudentMembership::STATUSES[:accepted])
        end
      end

      it "be able to have it's groupings cloned correctly" do
        clone = create(:assignment, course: @assignment.course)
        number = StudentMembership.all.size + TaMembership.all.size
        clone.clone_groupings_from(@assignment.id)
        clone.groupings.reload  # clone.groupings needs to be "reloaded" to obtain the updated value (5 groups created)
        expect(@assignment.group_min).to eql(clone.group_min)
        expect(@assignment.group_max).to eql(clone.group_max)
        expect(@assignment.groupings.size).to eql(clone.groupings.size)
        # Since we clear between each test, there should be twice as much as previously
        expect(2 * number).to eql(StudentMembership.all.size + TaMembership.all.size)
      end
    end
    context 'with a group with 3 accepted students' do
      before :each do
        @grouping = create(:grouping, assignment: @assignment)
        @members = []
        3.times do
          @members.push create(:student_membership,
                               membership_status: StudentMembership::STATUSES[:accepted],
                               grouping: @grouping)
        end
        @source = @assignment
        @group = @grouping.group
      end
      context 'with another fresh assignment' do
        before :each do
          @target = create(:assignment, course: @source.course)
        end

        it 'clone all three members if none are hidden' do
          @target.clone_groupings_from(@source.id)
          3.times do |index|
            expect @members[index].role.has_accepted_grouping_for?(@target.id)
          end
          @group.groupings.reload
          expect(@group.groupings.find_by(assessment_id: @target.id)).not_to be_nil
        end

        it 'ignore a blocked student during cloning' do
          student = @members[0].role
          # hide the student
          student.hidden = true
          student.save
          # clone the groupings
          @target.clone_groupings_from(@source.id)
          # make sure the membership wasn't created for the hidden
          # student
          expect(student.has_accepted_grouping_for?(@target.id)).to be_falsey
          # and let's make sure that the other memberships were cloned
          expect(@members[1].role.has_accepted_grouping_for?(@target.id)).to be_truthy
          expect(@members[2].role.has_accepted_grouping_for?(@target.id)).to be_truthy
          expect(@group.groupings.find_by(assessment_id: @target.id)).not_to be_nil
        end

        it 'ignore two blocked students during cloning' do
          # hide the students
          @members[0].role.hidden = true
          @members[0].role.save
          @members[1].role.hidden = true
          @members[1].role.save
          # clone the groupings
          @target.clone_groupings_from(@source.id)
          # make sure the membership wasn't created for the hidden student
          expect(@members[0].role.has_accepted_grouping_for?(@target.id)).not_to be_truthy
          expect(@members[1].role.has_accepted_grouping_for?(@target.id)).not_to be_truthy
          # and let's make sure that the other membership was cloned
          expect @members[2].role.has_accepted_grouping_for?(@target.id)
          # and that the proper grouping was created
          expect(@group.groupings.find_by(assessment_id: @target.id)).not_to be_nil
        end

        it 'ignore grouping if all students hidden' do
          # hide all students
          3.times do |index|
            @members[index].role.hidden = true
            @members[index].role.save
          end

          # Get the Group that these students belong to for assignment_1
          expect @members[0].role.has_accepted_grouping_for?(@source.id)
          # clone the groupings
          @target.clone_groupings_from(@source.id)
          # make sure the membership wasn't created for hidden students
          3.times do |index|
            expect(@members[index].role.has_accepted_grouping_for?(@target.id)).to be_falsey
          end
          # and let's make sure that the grouping wasn't cloned
          expect(@group.groupings.find_by(assessment_id: @target.id)).to be_nil
        end
      end

      context 'with an assignment with other groupings' do
        before :each do
          @target = create(:assignment, course: @source.course)
          3.times do
            target_grouping = create(:grouping, assignment: @target)
            create(:student_membership,
                   membership_status: StudentMembership::STATUSES[:accepted],
                   grouping: target_grouping)
          end
        end
        it 'destroy all previous groupings if cloning was successful' do
          old_groupings = @target.groupings.to_a
          @target.clone_groupings_from(@source.id)
          old_groupings.each do |old_grouping|
            expect(@target.groupings.include?(old_grouping)).to be_falsey
          end
        end
      end
    end

    context 'tests on methods returning groups repos' do
      before :each do
        @assignment = create(:assignment,
                             due_date: 2.days.ago,
                             created_at: 42.days.ago,
                             assignment_properties_attributes: { invalid_override: true })
      end

      def grouping_count(groupings)
        submissions = 0
        groupings.each do |grouping|
          if grouping.current_submission_used
            submissions += 1
          end
        end
        submissions
      end

      context 'with a grouping that has a submission and a TA assigned ' do
        before :each do
          @grouping = create(:grouping, assignment: @assignment)
          @tamembership = create(:ta_membership, grouping: @grouping)
          @studentmembership = create(:student_membership,
                                      grouping: @grouping,
                                      membership_status: StudentMembership::STATUSES[:inviter])
          @submission = create(:submission, grouping: @grouping)
        end

        it 'be able to get a list of repository access URLs for each group' do
          expected_string = ''
          @assignment.groupings.each do |grouping|
            group = grouping.group
            expected_string += [group.group_name,
                                group.repository_external_access_url].to_csv
          end
          expect(expected_string).to eql(@assignment.get_repo_list), 'Repo access url list string is wrong!'
        end

        it 'be able to get a list of repository access URLs for each group with ssh keys' do
          expected_string = ''
          @assignment.groupings.each do |grouping|
            group = grouping.group
            expected_string += [group.group_name,
                                group.repository_external_access_url,
                                group.repository_ssh_access_url].to_csv
          end
          expect(expected_string).to eql(@assignment.get_repo_list(ssh: true)), 'Repo access url list string is wrong!'
        end

        context 'with two groups of a single student each' do
          before :each do
            2.times do
              g = create(:grouping, assignment: @assignment)
              s = create(:version_used_submission, grouping: g)
              r = s.current_result
              2.times do
                create(:rubric_mark, result: r, assignment: @assignment) # this is create marks under rubric criterion
                # if we create(:flexible_mark, groping: g)
                # or create(:checkbox_mark, grouping: g)
                # they should work as well
              end
              r.reload
              r.marking_state = Result::MARKING_STATES[:complete]
              r.save
            end
            @assignment.groupings.reload
          end

          it 'be able to get_repo_checkout_commands' do
            submissions = grouping_count(@assignment.groupings) # filter out without submission
            expect(submissions).to eql @assignment.get_repo_checkout_commands.size
          end

          it 'be able to get_repo_checkout_commands with spaces in group name ' do
            Group.all.each do |group|
              group.group_name = group.group_name + ' Test'
              group.save
            end
            submissions = grouping_count(@assignment.groupings) # filter out without submission
            expect(submissions).to eql @assignment.get_repo_checkout_commands.size
          end
        end

        context 'with two groups of a single student each with multiple submission' do
          before :each do
            2.times do
              g = create(:grouping, assignment: @assignment)
              # create 2 submission for each group
              2.times do
                s = create(:submission, grouping: g)
                r = s.get_latest_result
                2.times do
                  create(:rubric_mark, result: r, assignment: @assignment)
                end
                r.reload
                r.marking_state = Result::MARKING_STATES[:complete]
                r.save
              end
              g.save
            end
            create(:version_used_submission, grouping: @assignment.groupings.first)
            @assignment.groupings.reload
          end

          it 'be able to get_repo_checkout_commands' do
            submissions = grouping_count(@assignment.groupings) # filter out without submission
            expect(submissions).to eql @assignment.get_repo_checkout_commands.size
          end
        end
      end
    end
  end

  describe '#current_submissions_used' do
    before :each do
      @assignment = create(:assignment)
    end

    context 'when no groups have made a submission' do
      it 'returns an empty array' do
        expect(@assignment.current_submissions_used).to eq []
      end
    end

    context 'when one group has submitted' do
      before :each do
        @grouping = create(:grouping, assignment: @assignment)
      end

      describe 'once' do
        before :each do
          create(:version_used_submission, grouping: @grouping)
          @grouping.reload
        end

        it 'returns the group\'s submission' do
          expect(@assignment.current_submissions_used).to eq [@grouping.current_submission_used]
        end
      end

      describe 'more than once' do
        before :each do
          create(:submission, grouping: @grouping)
          create(:version_used_submission, grouping: @grouping)
          @grouping.reload
        end

        it 'returns the group\'s collected submission' do
          expect(@assignment.current_submissions_used).to eq [@grouping.current_submission_used]
        end
      end
    end

    context 'when multiple groups have submitted' do
      before :each do
        @groupings = Array.new(2) { create(:grouping, assignment: @assignment) }
        @groupings.each do |group|
          create(:version_used_submission, grouping: group)
          group.reload
        end
      end

      it 'returns those groups' do
        expect(@assignment.current_submissions_used)
          .to match_array(@groupings.map(&:current_submission_used))
      end
    end
  end

  describe '#ungraded_submission_results' do
    before :each do
      @assignment = create(:assignment)
      @student = create(:student)
      @grouping = create(:grouping_with_inviter, assignment: @assignment, inviter: @student)
      @submission = create(:version_used_submission, grouping: @grouping)
      @other_student = create(:student)
      @other_grouping = create(:grouping_with_inviter, assignment: @assignment, inviter: @other_student)
      @other_submission =
        create(:version_used_submission, grouping: @other_grouping)
    end

    context 'when no submissions have been graded' do
      it 'returns the submissions' do
        expect(@assignment.ungraded_submission_results.size).to eq 2
      end
    end

    context 'when submission(s) have been graded' do
      before :each do
        @result = @submission.current_result
        @result.marking_state = Result::MARKING_STATES[:complete]
        @result.save
      end

      describe 'one submission' do
        it 'does not return the graded submission' do
          expect(@assignment.ungraded_submission_results.size).to eq 1
        end
      end

      describe 'all submissions' do
        before :each do
          @other_result = @other_submission.current_result
          @other_result.marking_state = Result::MARKING_STATES[:complete]
          @other_result.save
        end

        it 'returns all of the results' do
          expect(@assignment.ungraded_submission_results.size).to eq 0
        end
      end
    end
  end

  describe '#display_for_note' do
    it 'display for note without seeing an exception' do
      @assignment = create(:assignment)
      expect { @assignment.display_for_note }.not_to raise_error
    end
  end

  describe '#section_start_time' do
    context 'with AssessmentSectionProperties disabled' do
      let(:assignment) { create :timed_assignment }

      context 'when no section is specified' do
        it 'returns the start time of the assignment' do
          expect(assignment.section_start_time(nil)).to be_within(1.second).of(assignment.start_time)
        end
      end

      context 'when a section is specified' do
        it 'returns the start time of the assignment' do
          section = create(:section)
          expect(assignment.section_start_time(section)).to be_within(1.second).of(assignment.start_time)
        end
      end
    end

    context 'with AssessmentSectionProperties enabled' do
      let(:assignment) { create :timed_assignment, assignment_properties_attributes: { section_due_dates_type: true } }

      context 'when no section is specified' do
        it 'returns the start time of the assignment' do
          expect(assignment.section_start_time(nil)).to be_within(1.second).of(assignment.start_time)
        end
      end

      context 'when a section is specified' do
        let(:section) { create :section }

        context 'that does not have AssessmentSectionProperties' do
          it 'returns the start time of the assignment' do
            expect(assignment.section_start_time(section)).to be_within(1.second).of(assignment.start_time)
          end
        end

        context 'that has AssessmentSectionProperties for another assignment' do
          let(:another_assignment) { create(:assignment) }
          it 'returns the start time of the assignment' do
            create(:assessment_section_properties, assessment: another_assignment)
            expect(assignment.section_start_time(section)).to be_within(1.second).of(assignment.start_time)
          end
        end

        context 'that has AssessmentSectionProperties for this assignment' do
          it 'returns the start time of the section' do
            assessment_section_properties = create(:assessment_section_properties,
                                                   assessment: assignment,
                                                   section: section,
                                                   start_time: 10.minutes.ago)
            expect(assignment.section_start_time(section)).to be_within(1.second)
              .of(assessment_section_properties.start_time)
          end
        end
      end
    end
  end

  describe '#section_due_date' do
    context 'with AssessmentSectionProperties disabled' do
      before :each do
        @assignment = create(:assignment, due_date: Time.current) # Default 'section_due_dates_type' is false
      end

      context 'when no section is specified' do
        it 'returns the due date of the assignment' do
          expect(@assignment.section_due_date(nil)).to eq @assignment.due_date
        end
      end

      context 'when a section is specified' do
        it 'returns the due date of the assignment' do
          section = create(:section)
          expect(@assignment.section_due_date(section)).to eq @assignment.due_date
        end
      end
    end

    context 'with AssessmentSectionProperties enabled' do
      before :each do
        @assignment = create(:assignment,
                             due_date: 1.day.ago,
                             assignment_properties_attributes: { section_due_dates_type: true })
      end

      context 'when no section is specified' do
        it 'returns the due date of the assignment' do
          expect(@assignment.section_due_date(nil).day).to eq 1.day.ago.day
        end
      end

      context 'when a section is specified' do
        before :each do
          @section = create(:section)
        end

        context 'that does not have a AssessmentSectionProperties' do
          it 'returns the due date of the assignment' do
            assessment_section_properties = @assignment.section_due_date(@section)
            expect(assessment_section_properties.day).to eq 1.day.ago.day
          end
        end

        context 'that has AssessmentSectionProperties for another assignment' do
          before :each do
            AssessmentSectionProperties.create(section: @section, assessment: create(:assignment), due_date: 2.days.ago)
          end

          it 'returns the due date of the assignment' do
            assessment_section_properties = @assignment.section_due_date(@section)
            expect(assessment_section_properties.day).to eq 1.day.ago.day
          end
        end

        context 'that has AssessmentSectionProperties for this assignment' do
          before :each do
            AssessmentSectionProperties.create(section: @section, assessment: @assignment, due_date: 2.days.ago)
          end

          it 'returns the due date of the section' do
            assessment_section_properties = @assignment.section_due_date(@section)
            expect(assessment_section_properties.day).to eq 2.days.ago.day
          end
        end
      end
    end
  end

  describe '#latest_due_date' do
    context 'when AssessmentSectionProperties are disabled' do
      before :each do
        @assignment = create(:assignment, due_date: Time.current) # Default 'section_due_dates_type' is false
      end

      it 'returns the due date of the assignment' do
        expect(@assignment.latest_due_date).to eq @assignment.due_date
      end
    end

    context 'when AssessmentSectionProperties are enabled' do
      before :each do
        @assignment = create(:assignment,
                             due_date: Time.current,
                             assignment_properties_attributes: { section_due_dates_type: true })
      end

      context 'and there are no AssessmentSectionProperties' do
        it 'returns the due date of the assignment' do
          expect(@assignment.latest_due_date).to eq @assignment.due_date
        end
      end

      context 'and AssessmentSectionProperties has the latest due date' do
        before :each do
          @assessment_section_properties = AssessmentSectionProperties.create(section: create(:section),
                                                                              assessment: @assignment,
                                                                              due_date: 1.day.from_now)
        end

        it 'returns the due date of that AssessmentSectionProperties' do
          due_date1 = @assignment.latest_due_date
          due_date2 = @assessment_section_properties.due_date
          expect(due_date1).to same_time_within_ms due_date2
        end
      end

      context 'and the assignment has the latest due date' do
        before :each do
          @assessment_section_properties = AssessmentSectionProperties.create(section: create(:section),
                                                                              assessment: @assignment,
                                                                              due_date: 1.day.ago)
        end

        it 'returns the due date of the assignment' do
          expect(@assignment.latest_due_date).to eq @assignment.due_date
        end
      end
    end
  end

  describe '#past_all_due_dates?' do
    context 'when the assignment is not past due' do
      before :each do
        @assignment = create(:assignment, due_date: 1.day.from_now)
      end

      context 'and AssessmentSectionProperties are disabled' do
        before :each do
          @assignment.assignment_properties.update(section_due_dates_type: false)
        end

        it 'returns false' do
          expect(@assignment.past_all_due_dates?).to be false
        end
      end

      context 'and there are AssessmentSectionProperties past due' do
        before :each do
          @assignment.assignment_properties.update(section_due_dates_type: true)
          @assessment_section_properties = AssessmentSectionProperties.create(section: create(:section),
                                                                              assessment: @assignment,
                                                                              due_date: 1.day.ago)
        end

        it 'returns false' do
          expect(@assignment.past_all_due_dates?).to be false
        end
      end
    end

    context 'when the assignment is past due' do
      before :each do
        @assignment = create(:assignment, due_date: 1.day.ago)
      end

      context 'and AssessmentSectionProperties are disabled' do
        before :each do
          @assignment.assignment_properties.update(section_due_dates_type: false)
        end

        it 'returns true' do
          expect(@assignment.past_all_due_dates?).to be true
        end
      end

      context 'and there is a AssessmentSectionProperties not past due' do
        before :each do
          @assignment.assignment_properties.update(section_due_dates_type: true)
          AssessmentSectionProperties.create(section: create(:section), assessment: @assignment,
                                             due_date: 1.day.from_now)
        end

        it 'returns false' do
          expect(@assignment.past_all_due_dates?).to be false
        end
      end
    end
  end

  describe '#grouping_past_due_date?' do
    context 'with AssessmentSectionProperties disabled' do
      before :each do
        @due_assignment = create(:assignment, due_date: 1.day.ago)
        @not_due_assignment = create(:assignment, due_date: 1.day.from_now)
      end

      context 'when no grouping is specified' do
        it 'returns based on due date of the assignment' do
          expect(@due_assignment.grouping_past_due_date?(nil)).to be true
          expect(@not_due_assignment.grouping_past_due_date?(nil)).to be false
        end
      end

      context 'when a grouping is specified' do
        it 'returns based on due date of the assignment' do
          due_grouping = create(:grouping, assignment: @due_assignment)
          not_due_grouping = create(:grouping, assignment: @not_due_assignment)
          expect(@due_assignment.grouping_past_due_date?(due_grouping)).to be true
          expect(@not_due_assignment.grouping_past_due_date?(not_due_grouping))
            .to be false
        end
      end
    end

    context 'with AssessmentSectionProperties enabled' do
      before :each do
        @assignment = create(:assignment, assignment_properties_attributes: { section_due_dates_type: true })
      end

      context 'when no grouping is specified' do
        it 'returns based on due date of the assignment' do
          @assignment.update(due_date: 1.day.ago)
          expect(@assignment.grouping_past_due_date?(nil)).to be true
          @assignment.update(due_date: 1.day.from_now)
          expect(@assignment.grouping_past_due_date?(nil)).to be false
        end
      end

      context 'when a grouping is specified' do
        before :each do
          @grouping = create(:grouping, assignment: @assignment)
          @section = create(:section)
          student = create(:student, section: @section)
          create(:inviter_student_membership, role: student, grouping: @grouping)
        end

        context 'that does not have an associated AssessmentSectionProperties' do
          it 'returns based on due date of the assignment' do
            @assignment.update(due_date: 1.day.ago)
            expect(@assignment.grouping_past_due_date?(@grouping.reload)).to be true
            @assignment.update(due_date: 1.day.from_now)
            expect(@assignment.grouping_past_due_date?(@grouping.reload)).to be false
          end
        end

        context 'that has an associated AssessmentSectionProperties' do
          before :each do
            @assessment_section_properties = AssessmentSectionProperties.create(section: @section,
                                                                                assessment: @assignment)
          end
          it 'returns based on the AssessmentSectionProperties of the grouping' do
            @assessment_section_properties.update(due_date: 1.day.from_now)
            @assignment.update(due_date: 1.day.ago)
            expect(@assignment.grouping_past_due_date?(@grouping)).to be false

            @assessment_section_properties.update(due_date: 1.day.ago)
            @assignment.update(due_date: 1.day.from_now)
            expect(@assignment.grouping_past_due_date?(@grouping)).to be true
          end
        end
      end
    end
  end

  describe '#section_names_past_due_date' do
    context 'with AssessmentSectionProperties disabled' do
      before :each do
        @assignment = create(:assignment) # Default 'section_due_dates_type' is false
      end

      context 'when the assignment is past due' do
        it 'returns one name for the assignment' do
          @assignment.update(due_date: 1.day.ago)

          expect(@assignment.section_names_past_due_date).to eq []
        end
      end

      context 'when the assignment is not past due' do
        it 'returns an empty array' do
          @assignment.update(due_date: 1.day.from_now)

          expect(@assignment.section_names_past_due_date).to eq []
        end
      end
    end

    context 'with AssessmentSectionProperties enabled' do
      before :each do
        @assignment = create(:assignment, assignment_properties_attributes: { section_due_dates_type: true })
      end

      describe 'one AssessmentSectionProperties' do
        before :each do
          @section = create(:section)
          @assessment_section_properties =
            AssessmentSectionProperties.create(section: @section, assessment: @assignment)
        end

        context 'that is past due' do
          it 'returns an array with the name of the section' do
            @assessment_section_properties.update(due_date: 1.day.ago)

            expect(@assignment.section_names_past_due_date)
              .to eq [@section.name]
          end
        end

        context 'that is not past due' do
          it 'returns an empty array' do
            @assessment_section_properties.update(due_date: 1.day.from_now)

            expect(@assignment.section_names_past_due_date).to eq []
          end
        end
      end

      describe 'two AssessmentSectionProperties' do
        before :each do
          @sections = Array.new(2) { create(:section) }
          @assessment_section_properties = @sections.map do |section|
            AssessmentSectionProperties.create(section: section, assessment: @assignment)
          end
          @section_names = @sections.map(&:name)
        end

        context 'where both are past due' do
          it 'returns an array with both section names' do
            @assessment_section_properties.each do |section_due_date|
              section_due_date.update(due_date: 1.day.ago)
            end

            expect(@assignment.section_names_past_due_date)
              .to match_array @section_names
          end
        end

        context 'where one is past due' do
          it 'returns an array with the name of that section' do
            @assessment_section_properties.first.update(due_date: 1.day.ago)
            @assessment_section_properties.last.update(due_date: 1.day.from_now)

            expect(@assignment.section_names_past_due_date)
              .to eq [@section_names.first]
          end
        end

        context 'where neither is past due' do
          it 'returns an empty array' do
            @assessment_section_properties.each do |section_due_date|
              section_due_date.update(due_date: 1.day.from_now)
            end

            expect(@assignment.section_names_past_due_date).to eq []
          end
        end
      end
    end
  end

  describe '#grade_distribution_array' do
    before :each do
      @assignment = create(:assignment)
      5.times { create(:rubric_criterion, assignment: @assignment) }
    end

    context 'when there are no submitted marks' do
      it 'returns the correct distribution' do
        expect(@assignment.grade_distribution_array)
          .to eq [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        expect(@assignment.grade_distribution_array(10))
          .to eq [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      end
    end

    context 'when there are submitted marks' do
      before :each do
        total_marks = [1, 9.6, 10, 9, 18.1, 21] # Max mark is 20.

        total_marks.each do |total_mark|
          g = create(:grouping, assignment: @assignment)
          s = create(:version_used_submission, grouping: g)

          result = s.get_latest_result
          result.total_mark = total_mark
          result.marking_state = Result::MARKING_STATES[:complete]
          result.marks.each do |m|
            m.update!(mark: (total_mark * 4.0 / 20).round)
          end
          result.save!
        end
      end

      context 'without an interval provided' do
        it 'returns distribution with default 20 intervals' do
          expect(@assignment.grade_distribution_array.size).to eq 20
        end

        it 'returns the correct distribution' do
          expect(@assignment.grade_distribution_array)
            .to eq [1, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]
        end
      end

      context 'with an interval provided' do
        it 'returns distribution in the provided interval' do
          expect(@assignment.grade_distribution_array(10).size).to eq 10
        end

        it 'returns the correct distribution' do
          expect(@assignment.grade_distribution_array(10)).to eq [1, 0, 0, 0, 3, 0, 0, 0, 0, 2]
        end
      end
    end
  end

  describe '#pass_collection_date?' do
    context 'when before due with no submission rule' do
      before :each do
        @assignment = create(:assignment, due_date: 2.days.from_now)
      end

      it 'returns false' do
        expect(@assignment.past_collection_date?).not_to be
      end
    end

    context 'when past due with no late submission rule' do
      context 'without sections' do
        before :each do
          @assignment = create(:assignment, due_date: 2.days.ago)
        end

        it 'returns true' do
          expect(@assignment.past_collection_date?).to be
        end
      end

      context 'with a section' do
        before :each do
          @assignment = create(:assignment,
                               due_date: 2.days.ago,
                               assignment_properties_attributes: { section_due_dates_type: true })
          @section = create(:section, name: 'section_name')
          AssessmentSectionProperties.create(section: @section, assessment: @assignment, due_date: 1.day.ago)
          student = create(:student, section: @section)
          @grouping = create(:grouping, assignment: @assignment)
          create(:accepted_student_membership,
                 grouping: @grouping,
                 role: student,
                 membership_status: StudentMembership::STATUSES[:inviter])
        end

        it 'returns true' do
          expect(@assignment.past_collection_date?).to be
        end
      end
    end
  end

  describe '#past_all_collection_dates?' do
    context 'when before due with no submission rule' do
      before :each do
        @assignment = create(:assignment, due_date: 2.days.from_now)
      end

      it 'returns false' do
        expect(@assignment.past_all_collection_dates?).not_to be
      end
    end

    context 'when past due with no late submission rule' do
      context 'without sections' do
        before :each do
          @assignment = create(:assignment, due_date: 2.days.ago)
        end

        it 'returns true' do
          expect(@assignment.past_all_collection_dates?).to be
        end
      end

      context 'with a section' do
        before :each do
          @assignment = create(:assignment,
                               due_date: 2.days.ago,
                               assignment_properties_attributes: { section_due_dates_type: true })
          @section1 = create(:section, name: 'section_1')
          @section2 = create(:section, name: 'section_2')
          AssessmentSectionProperties.create(section: @section1, assessment: @assignment, due_date: 1.day.ago)
          student = create(:student, section: @section1)
          @grouping1 = create(:grouping, assignment: @assignment)
          create(:accepted_student_membership,
                 grouping: @grouping1,
                 role: student,
                 membership_status: StudentMembership::STATUSES[:inviter])
        end

        context 'when both sections past due' do
          before :each do
            AssessmentSectionProperties.create(section: @section2, assessment: @assignment, due_date: 1.day.ago)
            student = create(:student, section: @section2)
            @grouping2 = create(:grouping, assignment: @assignment)
            create(:accepted_student_membership,
                   grouping: @grouping2,
                   role: student,
                   membership_status: StudentMembership::STATUSES[:inviter])
          end

          it 'returns true' do
            expect(@assignment.past_all_collection_dates?).to be
          end
        end

        context 'when one section due' do
          before :each do
            AssessmentSectionProperties.create(section: @section2, assessment: @assignment, due_date: 1.day.from_now)
            student = create(:student, section: @section2)
            @grouping2 = create(:grouping, assignment: @assignment)
            create(:accepted_student_membership,
                   grouping: @grouping2,
                   role: student,
                   membership_status: StudentMembership::STATUSES[:inviter])
          end

          it 'returns false' do
            expect(@assignment.past_all_collection_dates?).not_to be
          end
        end
      end
    end
  end

  describe '#results_average' do
    let(:assignment) { create :assignment }
    before do
      allow(assignment).to receive(:max_mark).and_return(10)
    end

    it 'returns 0 when there are no results' do
      allow(assignment).to receive(:completed_result_marks).and_return([])
      expect(assignment.results_average).to eq 0
    end

    it 'returns the correct number when there are completed results' do
      allow(assignment).to receive(:completed_result_marks).and_return([0, 1, 4, 7])
      expect(assignment.results_average).to eq(3.0 * 100 / assignment.max_mark)
    end

    it 'returns 0 when the assignment has a max_mark of 0' do
      allow(assignment).to receive(:max_mark).and_return(0)
      allow(assignment).to receive(:completed_result_marks).and_return([0, 0, 0, 0])
      expect(assignment.results_average).to eq 0
    end
  end

  describe '#results_median' do
    let(:assignment) { create :assignment }
    before do
      allow(assignment).to receive(:max_mark).and_return(10)
    end

    it 'returns 0 when there are no results' do
      allow(assignment).to receive(:completed_result_marks).and_return([])
      expect(assignment.results_median).to eq 0
    end

    it 'returns the correct number when there are completed results' do
      allow(assignment).to receive(:completed_result_marks).and_return([0, 1, 4, 7])
      expect(assignment.results_median).to eq(2.5 * 100 / assignment.max_mark)
    end

    it 'returns 0 when the assignment has a max_mark of 0' do
      allow(assignment).to receive(:max_mark).and_return(0)
      allow(assignment).to receive(:completed_result_marks).and_return([0, 0, 0, 0])
      expect(assignment.results_median).to eq 0
    end
  end

  describe '#results_fails' do
    let(:assignment) { create :assignment }
    before do
      allow(assignment).to receive(:max_mark).and_return(10)
    end

    it 'returns 0 when there are no results' do
      allow(assignment).to receive(:completed_result_marks).and_return([])
      expect(assignment.results_fails).to eq 0
    end

    it 'returns the correct number when there are completed results' do
      allow(assignment).to receive(:completed_result_marks).and_return([0, 1, 4, 7])
      expect(assignment.results_fails).to eq 3
    end

    it 'returns 0 when the assignment has a max_mark of 0' do
      allow(assignment).to receive(:max_mark).and_return(0)
      allow(assignment).to receive(:completed_result_marks).and_return([0, 0, 0, 0])
      expect(assignment.results_fails).to eq 0
    end
  end

  describe '#results_zeros' do
    let(:assignment) { create :assignment }
    before do
      allow(assignment).to receive(:max_mark).and_return(10)
    end

    it 'returns 0 when there are no results' do
      allow(assignment).to receive(:completed_result_marks).and_return([])
      expect(assignment.results_zeros).to eq 0
    end

    it 'returns the correct number when there are completed results' do
      allow(assignment).to receive(:completed_result_marks).and_return([0, 1, 4, 7])
      expect(assignment.results_zeros).to eq 1
    end

    it 'returns the correct number when the assignment has a max_mark of 0' do
      allow(assignment).to receive(:max_mark).and_return(0)
      allow(assignment).to receive(:completed_result_marks).and_return([0, 0, 0, 0])
      expect(assignment.results_zeros).to eq 4
    end
  end

  describe '#current_submission_data' do
    let(:assignment) { create :assignment }
    let!(:groupings) { create_list :grouping_with_inviter, 3, assignment: assignment }

    context 'a TA user' do
      let(:ta) { create :ta }
      let!(:ta_membership) { create :ta_membership, grouping: groupings[0], role: ta }

      it 'should return results for groupings a TA is grading only' do
        data = assignment.current_submission_data(ta)
        expect(data.size).to eq 1
        expect(data[0][:_id]).to be groupings[0].id
      end

      context 'when hide_unassigned_criteria is true' do
        let(:assigned_criteria) { create :flexible_criterion, assignment: assignment, max_mark: 3 }
        let(:unassigned_criteria) { create :flexible_criterion, assignment: assignment, max_mark: 1 }
        let!(:criterion_ta_association) { create :criterion_ta_association, criterion: assigned_criteria, ta: ta }
        it 'should only include assigned criteria in max_mark' do
          assignment.update(hide_unassigned_criteria: true)
          data = assignment.current_submission_data(ta)
          expect(data[0][:max_mark]).to eq 3
        end
      end

      context 'when a grace period deduction has been applied' do
        let(:assignment) { create :assignment, submission_rule: create(:grace_period_submission_rule) }
        let!(:grace_period_deduction) do
          create(:grace_period_deduction,
                 membership: groupings[0].accepted_student_memberships.first,
                 deduction: 1)
        end
        it 'should include grace credit deductions' do
          data = assignment.current_submission_data(ta)
          expect(data.pluck(:grace_credits_used).compact).to contain_exactly(1)
        end
      end

      context 'there is an extra mark' do
        let(:submission) { create :version_used_submission, grouping: groupings[0] }
        let(:result) { create :complete_result, submission: submission }
        let!(:extra_mark) { create :extra_mark_points, result: result }
        it 'should include the extra mark in the total' do
          final_grade = submission.current_result.total_mark + extra_mark.extra_mark
          data = assignment.current_submission_data(ta)
          expect(data.pluck(:final_grade)).to include(final_grade)
          expect(data.select { |h| h.key? :final_grade }.count).to eq 1
        end
        context 'when the extra mark has a negative value' do
          let!(:extra_mark) { create :extra_mark_points, result: result, extra_mark: -100 }
          it 'should not reduce the total mark below zero' do
            data = assignment.current_submission_data(ta)
            expect(data.pluck(:final_grade)).to include(0)
            expect(data.select { |h| h.key? :final_grade }.count).to eq 1
          end
        end
      end
    end

    context 'a Student role' do
      let(:student) { create :student }
      it 'should return no results' do
        expect(assignment.current_submission_data(student)).to eq []
      end
    end

    context 'an Instructor user' do
      let(:instructor) { create :instructor }
      let(:tags) { create_list :tag, 3, role: instructor }
      let(:groupings_with_tags) { groupings.each_with_index { |g, i| g.update(tags: [tags[i]]) && g } }
      let(:data) { assignment.reload.current_submission_data(instructor) }
      let(:submission) { create :version_used_submission, grouping: groupings[0] }
      let(:released_result) { create :released_result, submission: submission }

      it 'should return results for all assignment groupings' do
        expect(data.size).to eq groupings.size
        expect(data.pluck(:_id)).to contain_exactly(*groupings.map(&:id))
      end

      it 'should include the group name' do
        expect(data.pluck(:group_name)).to contain_exactly(*groupings.map(&:group).map(&:group_name))
      end

      it 'should include tags' do
        tags_names = groupings_with_tags.map { |g| g&.tags&.to_a&.map(&:name) }
        expect(data.pluck(:tags)).to contain_exactly(*tags_names)
      end

      it 'should report the marking state as remark when a remark is requested' do
        submission.make_remark_result
        expect(data.pluck(:marking_state)).to contain_exactly('remark', 'before_due_date', 'before_due_date')
      end

      it 'should report the marking state as released when a result is released' do
        released_result
        expect(data.pluck(:marking_state)).to contain_exactly('released', 'before_due_date', 'before_due_date')
      end

      it 'should report the marking state as incomplete if collected' do
        submission
        expect(data.pluck(:marking_state)).to contain_exactly(Result::MARKING_STATES[:incomplete],
                                                              'before_due_date',
                                                              'before_due_date')
      end

      it 'should report the marking state as complete if collected and complete' do
        submission.current_result.update(marking_state: Result::MARKING_STATES[:complete])
        expect(data.pluck(:marking_state)).to contain_exactly(Result::MARKING_STATES[:complete],
                                                              'before_due_date',
                                                              'before_due_date')
      end

      it 'should report the marking state as before the due date if it is before the due date' do
        expect(data.pluck(:marking_state)).to contain_exactly('before_due_date',
                                                              'before_due_date',
                                                              'before_due_date')
      end

      it 'should report the marking state as not collected if it is after the due date but not collected' do
        assignment.update(due_date: 1.day.ago)
        expect(data.pluck(:marking_state)).to contain_exactly('not_collected',
                                                              'not_collected',
                                                              'not_collected')
      end

      it 'should include a submission time if a non-empty submission exists' do
        time_stamp = I18n.l(submission.revision_timestamp.in_time_zone)
        expect(data.select { |h| h.key? :submission_time }.count).to eq 1
        expect(data.pluck(:submission_time)).to include(time_stamp)
      end

      it 'should not include a submission time if an empty submission exists' do
        submission.update(is_empty: true)
        expect(data.select { |h| h.key? :submission_time }.count).to eq 0
      end

      it 'should not include the result id if a result does not exist' do
        expect(data.select { |h| h.key? :result_id }.count).to eq 0
      end

      it 'should include the result id if a result exists' do
        result_id = submission.current_result.id
        expect(data.pluck(:result_id)).to include(result_id)
        expect(data.select { |h| h.key? :result_id }.count).to eq 1
      end

      it 'should not include the total mark if a result does not exist' do
        expect(data.select { |h| h.key? :final_grade }.count).to eq 0
      end

      it 'should include the total mark if a result exists' do
        final_grade = submission.current_result.total_mark
        expect(data.pluck(:final_grade)).to include(final_grade)
        expect(data.select { |h| h.key? :final_grade }.count).to eq 1
      end

      context 'there is an extra mark' do
        let(:result) { create :complete_result, submission: submission }
        let!(:extra_mark) { create :extra_mark_points, result: result }
        it 'should include the extra mark in the total' do
          final_grade = submission.current_result.total_mark + extra_mark.extra_mark
          expect(data.pluck(:final_grade)).to include(final_grade)
          expect(data.select { |h| h.key? :final_grade }.count).to eq 1
        end
        context 'when the extra mark has a negative value' do
          let!(:extra_mark) { create :extra_mark_points, result: result, extra_mark: -100 }
          it 'should not reduce the total mark below zero' do
            expect(data.pluck(:final_grade)).to include(0)
            expect(data.select { |h| h.key? :final_grade }.count).to eq 1
          end
        end
      end

      context 'there are groups without members' do
        let!(:empty_groupings) { create_list :grouping, 2, assignment: assignment }

        it 'should not include member information for groups without members' do
          expect(data.count).to eq 5
          expect(data.select { |h| h.key? :members }.count).to eq 3
        end

        it 'should include member information for groups with members' do
          members = groupings.map { |g| g.accepted_students.joins(:user).pluck('users.user_name') }
          expect(data.pluck(:members).compact).to contain_exactly(*members)
        end
      end

      context 'there are groups with members in a given section' do
        let(:section_groupings) { create_list :grouping_with_inviter, 2, assignment: assignment }
        let!(:sections) { section_groupings.map { |g| (s = create(:section)) && g.inviter.update(section: s) && s } }

        it 'should include section information for groups in a section' do
          section_names = sections.map(&:name)
          expect(data.pluck(:section).compact).to contain_exactly(*section_names)
        end

        it 'should not include section information for groups not in a section' do
          expect(data.count).to eq 5
          expect(data.select { |h| h.key? :section }.count).to eq 2
        end
      end

      it 'should not include grace credit info if the submission rule is not a grace credit rule' do
        expect(data.select { |h| h.key? :grace_credits_used }.count).to eq 0
      end

      context 'the assignment uses grace credit deductions' do
        let(:assignment) { create :assignment, submission_rule: create(:grace_period_submission_rule) }
        let!(:grace_period_deduction) do
          create(:grace_period_deduction,
                 membership: groupings[0].accepted_student_memberships.first,
                 deduction: 1)
        end

        it 'should include grace credit deduction information for one grouping' do
          expect(data.pluck(:grace_credits_used).compact).to contain_exactly(1)
        end

        it 'should include null values for groupings without a penalty' do
          expect(data.pluck(:grace_credits_used).count(nil)).to be 2
        end
      end
      context '#zip_automated_test_files' do
        let(:content) { File.read assignment.zip_automated_test_files(instructor) }
        subject { content }
        it_behaves_like 'zip file download'
      end
    end
  end

  describe '#summary_test_results' do
    context 'an assignment with no test results' do
      let(:assignment) { create :assignment_with_criteria_and_results }

      it 'should return {}' do
        summary_test_results = assignment.summary_test_results
        expect(summary_test_results).to be_empty
      end
    end

    context 'an assignment with test results' do
      let(:assignment) { create :assignment_with_criteria_and_test_results }

      it 'has the correct group and test names' do
        summary_test_results = JSON.parse(assignment.summary_test_result_json)
        summary_test_results.map do |group_name, group|
          group.map do |test_group_name, test_group|
            test_group.each do |test_result|
              expect(test_result.fetch('name')).to eq test_group_name
              expect(test_result.fetch('group_name')).to eq group_name
              expect(test_result.key?('status')).to eq true
            end
          end
        end
      end

      it 'has the correct test result keys' do
        summary_test_results = JSON.parse(assignment.summary_test_result_json)
        expected_keys = %w[marks_earned
                           marks_total
                           output
                           name
                           test_result_name
                           test_groups_id
                           group_name
                           status
                           extra_info
                           error_type
                           id]
        summary_test_results.map do |_, group|
          group.map do |_, test_group|
            test_group.each do |test_result|
              expect(test_result.keys).to match_array expected_keys
            end
          end
        end
      end
    end
  end

  describe '#summary_json' do
    context 'a Student user' do
      let(:assignment) { create :assignment }
      let(:student) { create :student }

      it 'should return {}' do
        expect(assignment.summary_json(student)).to be_empty
      end
    end

    context 'a TA user' do
      let(:ta) { create :ta }
      let(:assignment_tag) { create :assignment }
      let(:tags) { create_list :tag, 3, role: ta }
      let(:groupings_with_tags) { groupings.each_with_index { |g, i| g.update(tags: [tags[i]]) && g } }
      let!(:groupings) { create_list :grouping_with_inviter, 3, assignment: assignment_tag }

      before :each do
        @assignment = create(:assignment_with_criteria_and_results)
      end

      context 'with no assigned students' do
        it 'has criteria columns' do
          expect(@assignment.summary_json(ta)[:criteriaColumns]).not_to be_empty
        end

        it 'has correct criteria information' do
          criteria_info = @assignment.summary_json(ta)[:criteriaColumns][0]
          expect(criteria_info).is_a? Hash
          expect(criteria_info.keys).to include(:Header, :accessor, :className)
        end
      end

      it 'has tags correct info' do
        Grouping.assign_all_tas(groupings.map(&:id), [ta.id], assignment_tag)
        tags_names = groupings_with_tags.map { |g| g&.tags&.to_a&.map(&:name) }
        data = assignment_tag.reload.summary_json(ta)[:data]
        expect(data.pluck(:tags)).to contain_exactly(*tags_names)
      end
    end

    context 'an Instructor user' do
      let(:instructor) { create :instructor }
      let(:assignment_tag) { create :assignment }
      let(:tags) { create_list :tag, 3, role: instructor }
      let(:groupings_with_tags) { groupings.each_with_index { |g, i| g.update(tags: [tags[i]]) && g } }
      let!(:groupings) { create_list :grouping_with_inviter, 3, assignment: assignment_tag }

      before :each do
        @assignment = create(:assignment_with_criteria_and_results_and_tas)
      end

      context 'with assigned students' do
        it 'has criteria columns' do
          expect(@assignment.summary_json(instructor)[:criteriaColumns]).not_to be_empty
        end

        it 'has correct criteria information' do
          criteria_info = @assignment.summary_json(instructor)[:criteriaColumns][0]
          expect(criteria_info).is_a? Hash
          expect(criteria_info.keys).to include(:Header, :accessor, :className)
        end

        it 'has tags correct info' do
          tags_names = groupings_with_tags.map { |g| g&.tags&.to_a&.map(&:name) }
          data = assignment_tag.reload.summary_json(instructor)[:data]
          expect(data.pluck(:tags)).to contain_exactly(*tags_names)
        end

        it 'has group data' do
          data = @assignment.summary_json(instructor)[:data]
          expected_keys = [
            :group_name,
            :section,
            :members,
            :marking_state,
            :final_grade,
            :criteria,
            :max_mark,
            :result_id,
            :submission_id,
            :tags,
            :total_extra_marks,
            :graders
          ]

          expect(data).not_to be_empty
          expect(data[0]).is_a? Hash
          expect(data[0].keys).to match_array expected_keys
        end

        it 'has group with members' do
          data = @assignment.summary_json(instructor)[:data]
          expect(data[0][:members]).not_to be_empty
          expect(data[0][:members][0]).not_to include(nil)
        end

        it 'has graders' do
          data = @assignment.summary_json(instructor)[:data]
          expect(data[0][:graders][0]).not_to include(nil)
        end

        context 'with an extra mark' do
          let(:grouping) { @assignment.groupings.first }
          let!(:extra_mark) { create :extra_mark_points, result: grouping.current_result }
          it 'should included the extra mark value' do
            data = @assignment.summary_json(instructor)[:data]
            grouping_data = data.select { |d| d[:group_name] == grouping.group.group_name }.first
            expect(grouping_data[:total_extra_marks]).to eq extra_mark.extra_mark
          end
          it 'should add the extra mark to the total mark' do
            data = @assignment.summary_json(instructor)[:data]
            grouping_data = data.select { |d| d[:group_name] == grouping.group.group_name }.first
            extra = grouping.current_result.extra_marks.pluck(:extra_mark).sum
            expect(grouping_data[:final_grade]).to eq(grouping.current_result.total_mark + extra)
          end
          context 'when the extra mark has a negative value' do
            let!(:extra_mark) { create :extra_mark_points, result: grouping.current_result, extra_mark: -100 }
            it 'should not reduce the total mark below zero' do
              data = @assignment.summary_json(instructor)[:data]
              grouping_data = data.select { |d| d[:group_name] == grouping.group.group_name }.first
              expect(grouping_data[:final_grade]).to eq(0)
            end
          end
          context 'and another extra mark' do
            let!(:extra_mark_percentage) { create :extra_mark, result: grouping.current_result }
            let(:percentage_extra) { (extra_mark_percentage.extra_mark * @assignment.max_mark / 100).round(2) }
            it 'should included both extra mark values' do
              data = @assignment.summary_json(instructor)[:data]
              grouping_data = data.select { |d| d[:group_name] == grouping.group.group_name }.first
              expect(grouping_data[:total_extra_marks]).to eq(extra_mark.extra_mark + percentage_extra)
            end
            it 'should add both extra marks to the total mark' do
              data = @assignment.summary_json(instructor)[:data]
              grouping_data = data.select { |d| d[:group_name] == grouping.group.group_name }.first
              total = grouping.current_result.total_mark + extra_mark.extra_mark + percentage_extra
              expect(grouping_data[:final_grade]).to eq total
            end
          end
        end
      end
    end
  end

  describe '#summary_csv' do
    context 'a Student user' do
      let(:assignment) { create :assignment }
      let(:student) { create :student }

      it 'should return ""' do
        expect(assignment.summary_csv(student)).to be_empty
      end
    end

    context 'a TA user' do
      let(:ta) { create :ta }
      let(:assignment) { create :assignment }

      it 'should return ""' do
        expect(assignment.summary_csv(ta)).to be_empty
      end
    end

    context 'an Instructor user' do
      let(:instructor) { create :instructor }

      before :each do
        @assignment = create(:assignment_with_criteria_and_results)
      end

      context 'with assigned students' do
        it 'has student data' do
          summary_string = @assignment.summary_csv(instructor)
          summary = CSV.parse(summary_string)

          expect(summary).to_not be_empty
          expect(summary[0]).to_not be_empty
          expect(summary[0]).to include('User name', 'Group', 'Final grade')
        end
      end
    end
  end

  describe '#upcoming' do
    # the upcoming method is only called in cases where the user is a student
    context 'a student with a grouping' do
      it 'returns false if an assignment was due before the current time' do
        a = create(:assignment_with_criteria_and_results, due_date: Time.current - (60 * 60 * 24))
        expect(a.upcoming(a.groupings.first.students.first)).to be false
      end

      it 'returns true if an assignment is due after the current time' do
        a = create(:assignment_with_criteria_and_results, due_date: Time.current + (60 * 60 * 24))
        expect(a.upcoming(a.groupings.first.students.first)).to be true
      end
    end

    context 'a student without a grouping' do
      it 'returns false if an assignment was due before the current time' do
        a = create(:assignment_with_criteria_and_results, due_date: Time.current - (60 * 60 * 24))
        expect(a.upcoming(create(:student))).to be false
      end

      it 'returns true if an assignment is due after the current time' do
        a = create(:assignment_with_criteria_and_results, due_date: Time.current + (60 * 60 * 24))
        expect(a.upcoming(create(:student))).to be true
      end
    end
  end
  describe '#starter_file_path' do
    let(:assignment) { create :assignment }
    it 'should return a path that includes the repository folder' do
      expect(File.basename(assignment.starter_file_path)).to eq assignment.repository_folder
    end
  end
  describe '#default_starter_file_group' do
    let(:assignment) { create :assignment }
    context 'no starter file groups' do
      it 'should return nil' do
        expect(assignment.default_starter_file_group).to be_nil
      end
    end
    context 'starter file groups exist' do
      let!(:starter_file_groups) { create_list :starter_file_group, 3, assignment: assignment }
      context 'default_starter_file_group_id is nil' do
        it 'should return the first starter file group' do
          expect(assignment.default_starter_file_group).to eq starter_file_groups.min_by(&:id)
        end
      end
      context 'default_starter_file_group_id refers to an existing object' do
        it 'should return the specified starter file group' do
          target = starter_file_groups.max_by(&:id)
          assignment.update!(default_starter_file_group_id: target.id)
          expect(assignment.default_starter_file_group).to eq target
        end
      end
    end
  end
  describe '#starter_file_mappings' do
    let(:assignment) { create :assignment }
    let!(:starter_file_group) { create :starter_file_group_with_entries, assignment: assignment }
    let!(:groupings) { create_list :grouping_with_inviter, 2, assignment: assignment }
    it 'returns the right data' do
      expected = groupings.map do |g|
        %w[q1 q2.txt].map do |entry|
          { group_name: g.group.group_name,
            starter_file_group_name: starter_file_group.name,
            starter_file_entry_path: entry }.transform_keys(&:to_s)
        end
      end.flatten.sort_by(&:values)
      expect(assignment.starter_file_mappings.sort_by(&:values)).to eq expected
    end
  end

  describe '#get_num_collected' do
    let(:instructor) { create(:instructor) }
    let(:ta) { create(:ta) }
    let(:assignment) { create(:assignment) }
    let(:grouping1) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let(:grouping2) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let!(:grouping3) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let!(:grouping4) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: false) }
    before :each do
      create(:ta_membership, role: ta, grouping: grouping1)
      create(:ta_membership, role: ta, grouping: grouping2)
    end
    context 'When user is instructor' do
      it 'should return no of collected submissions of all groupings' do
        expect(assignment.get_num_collected).to eq(3)
      end
    end
    context 'When user is TA' do
      it 'should return no of collected submissions for groupings assigned to them' do
        expect(assignment.get_num_collected(ta.id)).to eq(2)
      end
    end
  end

  describe '#get_num_marked' do
    let(:instructor) { create(:instructor) }
    let(:ta) { create(:ta) }
    let(:assignment) { create(:assignment) }
    let(:grouping1) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let(:grouping2) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let(:grouping3) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: true) }
    let(:grouping4) { create(:grouping_with_inviter_and_submission, assignment: assignment, is_collected: false) }
    let!(:result1) { create(:complete_result, submission: grouping1.submissions.first) }
    let!(:result2) { create(:incomplete_result, submission: grouping2.submissions.first) }
    let!(:result3) { create(:complete_result, submission: grouping3.submissions.first) }
    let!(:result4) { create(:incomplete_result, submission: grouping4.submissions.first) }
    before :each do
      create(:ta_membership, role: ta, grouping: grouping1)
      create(:ta_membership, role: ta, grouping: grouping2)
    end
    context 'When user is instructor' do
      it 'should return no of marked submissions of all groupings' do
        expect(assignment.get_num_marked).to eq(2)
      end

      context 'When there is a remark request that has not been completed' do
        let!(:result1_remark) { create(:remark_result, submission: grouping1.submissions.first) }

        it 'counts the grouping as not marked' do
          expect(assignment.get_num_marked).to eq(1)
        end
      end

      context 'Where there is a remark request that has been completed' do
        let!(:result1_remark) do
          create(:remark_result,
                 submission: grouping1.submissions.first,
                 marking_state: Result::MARKING_STATES[:complete])
        end

        it 'counts the grouping as marked' do
          expect(assignment.get_num_marked).to eq(2)
        end
      end
    end
    context 'When user is TA' do
      it 'should return no of marked submissions for groupings assigned to them' do
        expect(assignment.get_num_marked(ta.id)).to eq(1)
      end

      context 'When they are assigned a remark request that has not been completed' do
        let!(:result1_remark) { create(:remark_result, submission: grouping1.submissions.first) }

        it 'counts the grouping as not marked' do
          expect(assignment.get_num_marked(ta.id)).to eq(0)
        end
      end

      context 'When they are assigned a remark request that has been completed' do
        let!(:result1_remark) do
          create(:remark_result,
                 submission: grouping1.submissions.first,
                 marking_state: Result::MARKING_STATES[:complete])
        end

        it 'counts the grouping as marked' do
          expect(assignment.get_num_marked(ta.id)).to eq(1)
        end
      end

      context 'When they not assigned a remark request that has been completed' do
        let!(:result1_remark) do
          create(:remark_result,
                 submission: grouping3.submissions.first,
                 marking_state: Result::MARKING_STATES[:complete])
        end

        it 'does not count that grouping as marked' do
          expect(assignment.get_num_marked(ta.id)).to eq(1)
        end
      end

      context 'When the assignment has graders assigned to criteria' do
        let(:assignment2) do
          create(:assignment_with_criteria_and_results_with_remark,
                 assignment_properties_attributes: { assign_graders_to_criteria: true })
        end

        let(:new_grouping) { create(:grouping_with_inviter_and_submission, assignment: assignment2) }
        let(:new_result) { create(:incomplete_result, submission: new_grouping.current_submission_used) }
        before do
          create(:ta_membership, role: ta, grouping: assignment2.groupings.first)
          create(:ta_membership, role: ta, grouping: new_grouping)
        end

        it 'counts complete results when the grader is not assigned any criteria' do
          expect(assignment2.get_num_marked(ta.id)).to eq(1)
        end

        context 'When the grader is assigned to mark a criterion' do
          let!(:criterion_ta_association) do
            create(:criterion_ta_association, ta: ta, criterion: assignment2.criteria.first)
          end

          it 'counts results where the assigned criteria have marks' do
            m = Mark.find_by(result: new_result, criterion: assignment2.criteria.first)
            m.update(mark: 0)
            expect(assignment2.get_num_marked(ta.id)).to eq(2)
          end

          it 'does not count results where the assigned criteria do not have marks' do
            expect(assignment2.get_num_marked(ta.id)).to eq(1)
          end

          context 'Where there is a remark request' do
            let!(:remark_result) do
              create(:remark_result, submission: assignment2.groupings.first.current_submission_used)
            end

            it 'counts the remark result and not the original result' do
              expect(assignment2.get_num_marked(ta.id)).to eq(0)
            end
          end
        end
      end
    end
  end

  describe '#completed_result_marks' do
    let(:assignment) { create(:assignment) }
    let!(:criteria) { create_list(:rubric_criterion, 2, assignment: assignment, max_mark: 4) }

    shared_examples 'empty' do
      it 'returns an empty array' do
        expect(assignment.completed_result_marks).to be_empty
      end
    end

    context 'when there are no groupings' do
      it_returns 'empty'
    end

    context 'when there are groupings' do
      let!(:groupings) { create_list(:grouping_with_inviter_and_submission, 4, assignment: assignment) }

      context 'when there are no submissions' do
        it_returns 'empty'
      end

      context 'when there only incomplete results' do
        before { groupings }

        it_returns 'empty'
      end

      context 'when there are complete results' do
        let(:marks) { [1, 0, 4] }

        before do
          marks.zip(groupings).each do |m, g|
            criteria.each do |criterion|
              criterion.marks.find_or_create_by(result: g.current_result).update!(mark: m)
            end
            g.current_result.update!(total_mark: m * criteria.size, marking_state: Result::MARKING_STATES[:complete])
          end
        end

        it 'returns a list of sorted marks when no results are released' do
          expect(assignment.completed_result_marks).to eq [0, 2, 8]
        end

        it 'returns a list of sorted marks when some results are released' do
          groupings.first.current_result.update!(released_to_students: true)
          expect(assignment.completed_result_marks).to eq [0, 2, 8]
        end

        it 'returns a list of sorted marks that only includes results marked as complete' do
          result = assignment.current_results.find_by(total_mark: 2)
          result.update!(marking_state: Result::MARKING_STATES[:incomplete])
          expect(assignment.completed_result_marks).to eq [0, 8]
        end

        context 'when there is a remark result' do
          let(:original_result) { assignment.current_results.find_by(total_mark: 2) }
          let!(:remark_result) { create(:remark_result, submission: original_result.submission) }

          it 'does not include the original result or remark result when the latter is incomplete' do
            expect(assignment.completed_result_marks).to eq [0, 8]
          end

          it 'only includes the remark result when it is complete' do
            criteria.each do |c|
              c.marks.find_or_create_by(result: remark_result).update!(mark: 3)
            end
            remark_result.update!(total_mark: 6, marking_state: Result::MARKING_STATES[:complete])
            expect(assignment.completed_result_marks).to eq [0, 6, 8]
          end
        end
      end
    end
  end

  describe '#current_grader_data' do
    let!(:assignment) { create :assignment }

    context 'groupings with no members' do
      let!(:grouping) { create :grouping, assignment: assignment }
      it 'should not have sections' do
        actual_grouping = assignment.current_grader_data[:groups][0]
        expect(actual_grouping[:_id]).to eq(grouping.id)
        expect(actual_grouping[:section]).to be_nil
      end
    end

    context 'groupings with inviters that do not belong to a section' do
      let!(:student) { create :student }
      let!(:grouping) { create :grouping_with_inviter, inviter: student, assignment: assignment }
      it 'should not have sections' do
        actual_grouping = assignment.current_grader_data[:groups][0]
        expect(actual_grouping[:_id]).to eq(grouping.id)
        expect(actual_grouping[:section]).to be_nil
      end
    end

    context 'groupings that have inviters that do belong to sections' do
      let!(:section) { create :section }
      let!(:student) { create :student, section: section }
      let!(:grouping) { create :grouping_with_inviter, inviter: student, assignment: assignment }
      it 'should have sections' do
        actual_grouping = assignment.current_grader_data[:groups][0]
        expect(actual_grouping[:_id]).to eq(grouping.id)
        expect(actual_grouping[:section]).to eq(section.id)
      end
    end

    context 'groupings that have graders' do
      let(:section) { create :section }
      let(:student) { create :student, section: section }
      let(:grouping) { create :grouping_with_inviter, inviter: student, assignment: assignment }
      let(:ta) { create :ta }
      it 'returns correct graders' do
        Grouping.assign_all_tas([grouping], [ta.id], assignment)
        expect(assignment.current_grader_data[:graders][0][:_id]).to eq(ta.id)
      end
    end
  end
end
