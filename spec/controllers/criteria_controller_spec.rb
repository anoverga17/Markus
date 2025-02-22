describe CriteriaController do
  # TODO: add 'role is from a different course' shared tests to each route test below
  let(:instructor) { create :instructor }
  let(:course) { instructor.course }
  let(:assignment) { create :assignment }
  let(:grouping) { create :grouping, assignment: assignment }
  let(:submission) { create :submission, grouping: grouping }

  shared_examples 'callbacks' do
    before :each do
      @assignment = create(:assignment_with_criteria_and_results)
      @crit = create(criterion, assignment: @assignment, max_mark: 3.0)
      @assignment.groupings.each do |grouping|
        create(:mark, result: grouping.current_result, mark: @crit.max_mark, criterion: @crit)
      end
    end
    describe 'An authenticated and authorized instructor doing a DELETE' do
      it 'should update the relevant assignment\'s stats' do
        old_average = @assignment.results_average
        old_median = @assignment.results_median
        delete_as instructor,
                  :destroy,
                  params: { course_id: course.id, id: @crit.id },
                  format: :js
        assignment.reload
        expect(@assignment.results_median).to be >= old_median
        expect(@assignment.results_average).to be >= old_average
      end
    end
    context 'when changing the bonus' do
      it 'should be able to update the bonus value' do
        get_as instructor,
               :update,
               params: { course_id: course.id, id: @crit.id,
                         criterion => { name: 'one', bonus: true } },
               format: :js
        expect(@crit.reload.bonus).to be true
      end

      it 'should update the relevant assignment\'s stats' do
        old_average = @assignment.results_average
        old_median = @assignment.results_median
        get_as instructor,
               :update,
               params: { course_id: course.id, id: @crit.id,
                         criterion => { name: 'one', bonus: true } },
               format: :js
        @assignment.reload
        expect(@assignment.results_median).to be >= old_median
        expect(@assignment.results_average).to be >= old_average
      end
    end
  end

  describe 'Using Checkbox Criterion' do
    let(:criterion) { :checkbox_criterion }
    include_examples 'callbacks'
  end

  describe 'Using Flexible Criteria' do
    let(:criterion) { :flexible_criterion }
    include_examples 'callbacks'

    let(:flexible_criterion) do
      create(:flexible_criterion,
             assignment: assignment,
             position: 1,
             name: 'Flexible Criterion')
    end
    let(:flexible_criterion2) do
      create(:flexible_criterion,
             assignment: assignment,
             position: 2,
             name: 'Flexible Criterion 2')
    end
    describe 'An unauthenticated and unauthorized user doing a GET' do
      context '#index' do
        it 'should respond with redirect' do
          get :index, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#new' do
        it 'should respond with redirect' do
          get :new, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#edit' do
        it 'should respond with redirect' do
          get :edit, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update' do
        it 'should respond with redirect' do
          put :update, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#destroy' do
        it 'should respond with redirect' do
          delete :destroy, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update_positions' do
        it 'should respond with redirect' do
          get :update_positions, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context 'with an assignment' do
        context 'and a submission' do
          context '#edit' do
            it 'should respond with redirect' do
              get :edit, params: { course_id: course.id, id: 1 }
              is_expected.to respond_with :redirect
            end
          end
        end
      end

      context '#download' do
        it 'should respond with redirect' do
          get :download, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end
    end

    describe 'An unauthenticated and unauthorized user doing a POST' do
      context '#index' do
        it 'should respond with redirect' do
          post :index, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#new' do
        it 'should respond with redirect' do
          post :new, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update' do
        it 'should respond with redirect' do
          put :update, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#edit' do
        it 'should respond with redirect' do
          post :edit, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#destroy' do
        it 'should respond with redirect' do
          delete :destroy, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end
    end

    describe 'An authenticated and authorized instructor doing a GET' do
      context '#index' do
        before(:each) do
          get_as instructor, :index, params: { course_id: course.id, assignment_id: assignment.id }
        end
        it 'should respond assign assignment and criteria' do
          expect(assigns(:assignment)).to be_truthy
          expect(assigns(:criteria)).to be_truthy
        end

        it 'should render the edit template' do
          is_expected.to render_template(:index)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#new' do
        before(:each) do
          get_as instructor,
                 :new,
                 params: { course_id: course.id, assignment_id: assignment.id },
                 format: :js
        end

        it 'should respond with appropriate content' do
          expect(assigns(:assignment)).to be_truthy
        end

        it 'should render the new template' do
          is_expected.to render_template(:new)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#edit' do
        before(:each) do
          get_as instructor,
                 :edit,
                 params: { course_id: course.id, id: flexible_criterion.id },
                 format: :js
        end

        it 'should respond with appropriate content' do
          expect(assigns(:criterion)).to be_truthy
        end

        it 'should render edit template' do
          is_expected.to render_template(:edit)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#update' do
        context 'with errors' do
          before(:each) do
            expect_any_instance_of(FlexibleCriterion).to receive(:save).and_return(false)
            expect_any_instance_of(FlexibleCriterion).to(
              receive(:errors).and_return(ActiveModel::Errors.new(flexible_criterion))
            )

            get_as instructor,
                   :update,
                   params: { course_id: course.id, id: flexible_criterion.id,
                             flexible_criterion: { name: 'one', max_mark: 10 } },
                   format: :js
          end

          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
          end

          it 'should respond with unprocessable entity' do
            is_expected.to respond_with(:unprocessable_entity)
          end
        end

        context 'without errors' do
          before(:each) do
            get_as instructor,
                   :update,
                   params: { course_id: course.id, id: flexible_criterion.id,
                             flexible_criterion: { name: 'one', max_mark: 10 } },
                   format: :js
          end

          it 'successfully assign criterion' do
            expect(assigns(:criterion)).to be_truthy
          end

          it 'should render the update template' do
            is_expected.to render_template(:update)
          end
        end
      end
    end

    describe 'An authenticated and authorized instructor doing a POST' do
      context '#index' do
        before(:each) do
          post_as instructor, :index, params: { course_id: course.id, assignment_id: assignment.id }
        end
        it 'should respond with appropriate content' do
          expect(assigns(:assignment)).to be_truthy
          expect(assigns(:criteria)).to be_truthy
        end

        it 'should render the index template' do
          is_expected.to render_template(:index)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#create' do
        context 'with save error' do
          before(:each) do
            expect_any_instance_of(FlexibleCriterion).to receive(:save).and_return(false)
            expect_any_instance_of(FlexibleCriterion).to receive(:errors).and_return(ActiveModel::Errors.new(self))
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id,
                              flexible_criterion: { name: 'first', max_mark: 10 },
                              new_criterion_prompt: 'first', criterion_type: 'FlexibleCriterion' },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end

          it 'should respond with unprocessable entity' do
            is_expected.to respond_with(:unprocessable_entity)
          end
        end

        context 'without error on an assignment as the first criterion' do
          before(:each) do
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id, flexible_criterion: { name: 'first' },
                              new_criterion_prompt: 'first', criterion_type: 'FlexibleCriterion', max_mark_prompt: 10 },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end
          it 'should render the create template' do
            is_expected.to render_template(:'criteria/create')
          end

          it 'should respond with success' do
            is_expected.to respond_with(:success)
          end
        end

        context 'without error on an assignment that already has criteria' do
          before(:each) do
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id, flexible_criterion: { name: 'first' },
                              new_criterion_prompt: 'first', criterion_type: 'FlexibleCriterion', max_mark_prompt: 10 },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end
          it 'should render the create template' do
            is_expected.to render_template(:'criteria/create')
          end

          it 'should respond with success' do
            is_expected.to respond_with(:success)
          end
        end
      end

      context '#edit' do
        before(:each) do
          post_as instructor,
                  :edit,
                  params: { course_id: course.id, id: flexible_criterion.id },
                  format: :js
        end

        it ' should respond with appropriate content' do
          expect(assigns(:criterion)).to be_truthy
        end

        it 'should render the edit template' do
          is_expected.to render_template(:edit)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      it 'should be able to update_positions' do
        post_as instructor,
                :update_positions,
                params: { course_id: course.id, criterion: [flexible_criterion2.id, flexible_criterion.id],
                          assignment_id: assignment.id },
                format: :js
        is_expected.to render_template
        is_expected.to respond_with(:success)

        c1 = FlexibleCriterion.find(flexible_criterion.id)
        expect(c1.position).to eql(2)
        c2 = FlexibleCriterion.find(flexible_criterion2.id)
        expect(c2.position).to eql(1)
      end
    end

    describe 'An authenticated and authorized instructor doing a DELETE' do
      it ' should be able to delete the criterion' do
        delete_as instructor,
                  :destroy,
                  params: { course_id: course.id, id: flexible_criterion.id },
                  format: :js
        expect(assigns(:criterion)).to be_truthy
        i18t_strings = [I18n.t('flash.criteria.destroy.success')].map { |f| extract_text f }
        expect(i18t_strings).to eql(flash[:success].map { |f| extract_text f })
        is_expected.to respond_with(:success)

        expect { FlexibleCriterion.find(flexible_criterion.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Using Rubric Criteria' do
    let(:criterion) { :rubric_criterion }
    include_examples 'callbacks'

    let(:rubric_criterion) do
      create(:rubric_criterion,
             assignment: assignment,
             position: 1,
             name: 'Rubric Criterion')
    end
    let(:rubric_criterion2) do
      create(:rubric_criterion,
             assignment: assignment,
             position: 2,
             name: 'Rubric Criterion 2')
    end
    describe 'An unauthenticated and unauthorized user doing a GET' do
      context '#index' do
        it 'should respond with redirect' do
          get :index, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#new' do
        it 'should respond with redirect' do
          get :new, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#edit' do
        it 'should respond with redirect' do
          get :edit, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end

        context 'with an assignment' do
          context 'and a submission' do
            context '#edit' do
              it 'should respond with redirect' do
                get :edit, params: { course_id: course.id, assignment_id: assignment.id, id: 1 }
                is_expected.to respond_with :redirect
              end
            end
          end
        end
      end

      context '#destroy' do
        it 'should respond with redirect' do
          delete :destroy, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update' do
        it 'should respond with redirect' do
          put :update, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update_positions' do
        it 'should respond with redirect' do
          get :update_positions, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#download' do
        it 'should respond with redirect' do
          get :download, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end
    end

    describe 'An unauthenticated and unauthorized user doing a POST' do
      context '#index' do
        it 'should respond with redirect' do
          post :index, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#new' do
        it 'should respond with redirect' do
          post :new, params: { course_id: course.id, assignment_id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#edit' do
        it 'should respond with redirect' do
          post :edit, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#update' do
        it 'should respond with redirect' do
          put :update, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end

      context '#destroy' do
        it 'should respond with redirect' do
          delete :destroy, params: { course_id: course.id, id: 1 }
          is_expected.to respond_with :redirect
        end
      end
    end

    describe 'An authenticated and authorized instructor doing a GET' do
      context '#index' do
        before(:each) do
          get_as instructor, :index, params: { course_id: course.id, assignment_id: assignment.id }
        end
        it 'should respond assign assignment and criteria' do
          expect(assigns(:assignment)).to be_truthy
          expect(assigns(:criteria)).to be_truthy
        end

        it 'should render the edit template' do
          is_expected.to render_template(:index)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#new' do
        before(:each) do
          get_as instructor,
                 :new,
                 params: { course_id: course.id, assignment_id: assignment.id },
                 format: :js
        end

        it 'should respond with appropriate content' do
          expect(assigns(:assignment)).to be_truthy
        end

        it 'should render the new template' do
          is_expected.to render_template(:new)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#edit' do
        before(:each) do
          get_as instructor,
                 :edit,
                 params: { course_id: course.id, id: rubric_criterion.id },
                 format: :js
        end

        it 'should respond with appropriate content' do
          expect(assigns(:criterion)).to be_truthy
        end

        it 'should render edit template' do
          is_expected.to render_template(:edit)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#update' do
        context 'with errors' do
          before(:each) do
            expect_any_instance_of(RubricCriterion).to receive(:save).and_return(false)
            expect_any_instance_of(RubricCriterion).to(
              receive(:errors).and_return(ActiveModel::Errors.new(rubric_criterion))
            )
            get_as instructor,
                   :update,
                   params: { course_id: course.id, id: rubric_criterion.id,
                             rubric_criterion: { name: 'one', max_mark: 10 } },
                   format: :js
          end

          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
          end

          it 'should respond with unprocessable entity' do
            is_expected.to respond_with(:unprocessable_entity)
          end
        end

        context 'without errors' do
          before(:each) do
            get_as instructor,
                   :update,
                   params: { course_id: course.id, id: rubric_criterion.id,
                             rubric_criterion: { name: 'one', max_mark: 10 } },
                   format: :js
          end

          it 'successfully assign criterion' do
            expect(assigns(:criterion)).to be_truthy
          end

          it 'should render the update template' do
            is_expected.to render_template(:update)
          end
        end
      end
    end

    describe 'An authenticated and authorized instructor doing a POST' do
      context '#index' do
        before(:each) do
          post_as instructor, :index, params: { course_id: course.id, assignment_id: assignment.id }
        end
        it 'should respond with appropriate content' do
          expect(assigns(:assignment)).to be_truthy
          expect(assigns(:criteria)).to be_truthy
        end

        it 'should render the index template' do
          is_expected.to render_template(:index)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      context '#create' do
        context 'with save error' do
          before(:each) do
            expect_any_instance_of(RubricCriterion).to receive(:save).and_return(false)
            expect_any_instance_of(RubricCriterion).to receive(:errors).and_return(ActiveModel::Errors.new(self))
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id, max_mark_prompt: 10,
                              new_criterion_prompt: 'first', criterion_type: 'RubricCriterion' },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end

          it 'should respond with unprocessable entity' do
            is_expected.to respond_with(:unprocessable_entity)
          end
        end

        context 'without error on an assignment as the first criterion' do
          before(:each) do
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id,
                              new_criterion_prompt: 'first', criterion_type: 'RubricCriterion', max_mark_prompt: 10 },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end
          it 'should render the create template' do
            is_expected.to render_template(:'criteria/create')
          end

          it 'should respond with success' do
            is_expected.to respond_with(:success)
          end
        end

        context 'without error on an assignment that already has criteria' do
          before(:each) do
            post_as instructor,
                    :create,
                    params: { course_id: course.id, assignment_id: assignment.id, rubric_criterion: { name: 'first' },
                              new_criterion_prompt: 'first', criterion_type: 'RubricCriterion', max_mark_prompt: 10 },
                    format: :js
          end
          it 'should respond with appropriate content' do
            expect(assigns(:criterion)).to be_truthy
            expect(assigns(:assignment)).to be_truthy
          end
          it 'should render the create template' do
            is_expected.to render_template(:'criteria/create')
          end

          it 'should respond with success' do
            is_expected.to respond_with(:success)
          end
        end
      end

      context '#edit' do
        before(:each) do
          post_as instructor,
                  :edit,
                  params: { course_id: course.id, id: rubric_criterion.id },
                  format: :js
        end

        it ' should respond with appropriate content' do
          expect(assigns(:criterion)).to be_truthy
        end

        it 'should render the edit template' do
          is_expected.to render_template(:edit)
        end

        it 'should respond with success' do
          is_expected.to respond_with(:success)
        end
      end

      describe '#update_positions' do
        context 'when all criteria id can be found under assignment' do
          let(:rubric_criterion) do
            create(:rubric_criterion, assignment: assignment, position: 1)
          end
          let(:rubric_criterion2) do
            create(:rubric_criterion, assignment: assignment, position: 2)
          end
          it 'should be able to update_positions' do
            post_as instructor,
                    :update_positions,
                    params: { course_id: course.id, criterion: [rubric_criterion2.id, rubric_criterion.id],
                              assignment_id: assignment.id },
                    format: :js
            is_expected.to render_template
            is_expected.to respond_with(:success)

            c1 = RubricCriterion.find(rubric_criterion.id)
            expect(c1.position).to eql(2)
            c2 = RubricCriterion.find(rubric_criterion2.id)
            expect(c2.position).to eql(1)
          end
        end

        context 'when there exists criteria not under current assignment' do
          let(:assignment2) { create :assignment }
          let(:rubric_criterion) do
            create(:rubric_criterion, assignment: assignment, position: 1)
          end
          let(:rubric_criterion2) do
            create(:rubric_criterion, assignment: assignment, position: 2)
          end
          let(:rubric_criterion3) do
            create(:rubric_criterion, assignment: assignment2, position: 3)
          end
          before do
            post_as instructor,
                    :update_positions,
                    params: { course_id: course.id,
                              criterion: [rubric_criterion3.id,
                                          rubric_criterion2.id,
                                          rubric_criterion.id],
                              assignment_id: assignment.id },
                    format: :js
          end

          it 'does not update position' do
            c1 = RubricCriterion.find(rubric_criterion.id)
            expect(c1.position).to eql(1)
            c2 = RubricCriterion.find(rubric_criterion2.id)
            expect(c2.position).to eql(2)
            c3 = RubricCriterion.find(rubric_criterion3.id)
            expect(c3.position).to eql(3)
          end

          it 'displays an error message' do
            expect(flash[:error].map { |f| extract_text f })
              .to eq([I18n.t('criteria.errors.criteria_not_found')].map { |f| extract_text f })
          end
        end
      end
    end

    describe 'An authenticated and authorized instructor doing a DELETE' do
      it ' should be able to delete the criterion' do
        delete_as instructor,
                  :destroy,
                  params: { course_id: course.id, id: rubric_criterion.id },
                  format: :js
        expect(assigns(:criterion)).to be_truthy
        i18t_string = [I18n.t('flash.criteria.destroy.success')].map { |f| extract_text f }
        expect(i18t_string).to eql(flash[:success].map { |f| extract_text f })
        is_expected.to respond_with(:success)

        expect { RubricCriterion.find(rubric_criterion.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'An authenticated and authorized instructor performing yml actions' do
    let!(:rubric_criterion) do
      create(:rubric_criterion,
             assignment: assignment,
             position: 1,
             name: 'Rubric Criterion')
    end
    let!(:flexible_criterion) do
      create(:flexible_criterion,
             assignment: assignment,
             position: 2,
             name: 'Flexible Criterion')
    end
    let!(:checkbox_criterion) do
      create(:checkbox_criterion,
             assignment: assignment,
             position: 3,
             name: 'Checkbox Criterion')
    end
    let(:mixed_file) { fixture_file_upload('criteria/upload_yml_mixed.yaml', 'text/yaml') }
    let(:invalid_mixed_file) { fixture_file_upload('criteria/upload_yml_mixed_invalid.yaml', 'text/yaml') }
    let(:missing_levels_file) { fixture_file_upload('criteria/upload_yml_missing_levels.yaml', 'text/yaml') }
    let(:empty_file) { fixture_file_upload('empty_file', 'text/yaml') }
    let(:test_upload_download_file) { fixture_file_upload('criteria/criteria_upload_download.yaml', 'text/yaml') }
    let(:expected_download) { fixture_file_upload('criteria/download_yml_output.yaml', 'text/yaml') }
    let(:round_max_mark_file) { fixture_file_upload('criteria/round_max_mark.yaml', 'text/yaml') }
    let(:partially_valid_file) { fixture_file_upload('criteria/partially_valid_file.yaml', 'text/yaml') }
    let(:uploaded_file) { fixture_file_upload('criteria/upload_yml_mixed.yaml', 'text/yaml') }
    let(:no_type_file) { fixture_file_upload('criteria/marking_criteria_no_type.yml', 'text/yaml') }

    context 'When a file containing a mixture of entries is uploaded' do
      it 'raises an error if the file does not include any criteria' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: empty_file }

        expect(flash[:error].map { |f| extract_text f })
          .to eq([I18n.t('upload_errors.blank')].map { |f| extract_text f })
      end

      it 'deletes all criteria previously created' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.where(type: 'RubricCriterion').find_by(name: rubric_criterion.name)).to be_nil
        expect(assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: flexible_criterion.name)).to be_nil
        expect(assignment.criteria.where(type: 'CheckboxCriterion').find_by(name: checkbox_criterion.name)).to be_nil
      end

      it 'maintains the order between entries and positions for criteria' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.map { |cr| [cr.name, cr.position] })
          .to match_array([['cr30', 1],
                           ['cr20', 2],
                           ['cr100', 3],
                           ['cr40', 4],
                           ['cr80', 5],
                           ['cr50', 6],
                           ['cr60', 7],
                           ['cr90', 8]])
      end

      it 'creates all criteria with properly formatted entries' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.pluck(:name)).to contain_exactly('cr30',
                                                                    'cr20',
                                                                    'cr100',
                                                                    'cr80',
                                                                    'cr60',
                                                                    'cr90',
                                                                    'cr40',
                                                                    'cr50')
        expect(flash[:success].map { |f| extract_text f })
          .to eq([I18n.t('upload_success', count: 8)].map { |f| extract_text f })
      end

      it 'creates rubric criteria with properly formatted entries' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }
        expect(assignment.criteria.where(type: 'RubricCriterion').pluck(:name)).to contain_exactly('cr30', 'cr90')
        cr1 = assignment.criteria.where(type: 'RubricCriterion').find_by(name: 'cr30')
        expect(cr1.levels.size).to eq(5)
        expect(cr1.max_mark).to eq(5.0)
        expect(cr1.bonus).to be true
        expect(cr1.ta_visible).to be false
        expect(cr1.peer_visible).to be true
        # Since there are only 5 levels in this rubric criterion, if each of the following queries return an entity,
        # then this rubric criterion is properly sat up.
        expect(cr1.levels.find_by(name: 'Beginner', description: 'Fail', mark: 0)).not_to be_nil
        expect(cr1.levels.find_by(name: 'Hmm', description: 'Almost fail', mark: 1)).not_to be_nil
        expect(cr1.levels.find_by(name: 'Average', description: 'Not bad', mark: 2)).not_to be_nil
        expect(cr1.levels.find_by(name: 'Good', description: 'Alright', mark: 3)).not_to be_nil
        expect(cr1.levels.find_by(name: 'Excellent', description: 'Impressive', mark: 5)).not_to be_nil

        cr2 = assignment.criteria.where(type: 'RubricCriterion').find_by(name: 'cr90')
        expect(cr2.max_mark).to eq(4.6)
        expect(cr2.levels.size).to eq(5)
        expect(cr2.ta_visible).to be true
        expect(cr2.peer_visible).to be false
        expect(cr2.bonus).to be false
      end

      it 'creates flexible criteria with properly formatted entries' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.where(type: 'FlexibleCriterion').pluck(:name))
          .to contain_exactly('cr20', 'cr50', 'cr80', 'cr60')

        cr80 = assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr80')
        expect(cr80.max_mark).to eq(10.0)
        expect(cr80.description).to eq('')
        expect(cr80.ta_visible).to be true
        expect(cr80.peer_visible).to be true
        expect(cr80.bonus).to be false

        cr20 = assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr20')
        expect(cr20.max_mark).to eq(2.0)
        expect(cr20.description).to eq('I am flexible')
        expect(cr20.ta_visible).to be true
        expect(cr20.peer_visible).to be true
        expect(cr20.bonus).to be false

        cr50 = assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr50')
        expect(cr50.bonus).to be true
        expect(cr50.max_mark).to eq(1.0)
        expect(cr50.description).to eq('Another flexible.')
        expect(cr50.ta_visible).to be true
        expect(cr50.peer_visible).to be false

        cr60 = assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr60')
        expect(cr60.max_mark).to eq(10.0)
        expect(cr60.description).to eq('')
        expect(cr60.ta_visible).to be true
        expect(cr60.peer_visible).to be false
        expect(cr60.bonus).to be false
      end

      it 'creates checkbox criteria with properly formatted entries' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.where(type: 'CheckboxCriterion').pluck(:name)).to contain_exactly('cr100', 'cr40')
        cr1 = assignment.criteria.where(type: 'CheckboxCriterion').find_by(name: 'cr100')
        expect(cr1.bonus).to be true
        expect(cr1.max_mark).to eq(5.0)
        expect(cr1.description).to eq('I am checkbox')
        expect(cr1.ta_visible).to be true
        expect(cr1.peer_visible).to be false
      end

      it 'creates criteria being case insensitive with the type given' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.where(type: 'FlexibleCriterion').pluck(:name))
          .to contain_exactly('cr20', 'cr80', 'cr60', 'cr50')
      end

      it 'creates criteria that lack a description' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }

        expect(assignment.criteria.where(type: 'FlexibleCriterion').pluck(:name)).to include('cr80')
        expect(assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr80').description).to eq('')
      end

      it 'creates criteria with the default visibility options if these are not given in the entries' do
        post_as instructor, :upload,
                params: { course_id: course.id, assignment_id: assignment.id, upload_file: mixed_file }
        expect(assignment.criteria.pluck(:name)).to include('cr100', 'cr60')
        expect(assignment.criteria.where(type: 'CheckboxCriterion').find_by(name: 'cr100').ta_visible).to be true
        expect(assignment.criteria.where(type: 'CheckboxCriterion').find_by(name: 'cr100').peer_visible).to be false
        expect(assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr60').ta_visible).to be true
        expect(assignment.criteria.where(type: 'FlexibleCriterion').find_by(name: 'cr60').peer_visible).to be false
      end

      it 'creates criteria with rounded (up to first digit after decimal point) maximum mark' do
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: round_max_mark_file }
        expect(assignment.criteria.where(type: 'RubricCriterion').first.name).to eq('cr90')

        expect(assignment.criteria.where(type: 'RubricCriterion').first.max_mark).to eq(4.6)
      end
      it 'does not create criteria with format errors in entries' do
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: invalid_mixed_file }

        expect(assignment.criteria.pluck(:name)).not_to include('cr40', 'cr50', 'cr70')
        expect(flash[:error].map { |f| extract_text f })
          .to eq([I18n.t('criteria.errors.invalid_format') + ' cr40, cr70, cr50'].map { |f| extract_text f })
      end

      it 'does not create criteria with an invalid mark' do
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: invalid_mixed_file }

        expect(assignment.criteria.pluck(:name)).not_to include('cr40', 'cr50')
      end

      it 'does not create rubric criteria when levels are missing' do
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: missing_levels_file }

        expect(assignment.criteria.where(name: %w[no_levels empty_levels])).to be_empty
        expect(flash[:error].map { |f| extract_text f })
          .to eq([I18n.t('criteria.errors.invalid_format') + ' no_levels, empty_levels'].map { |f| extract_text f })
      end

      it 'does not create criteria that have both visibility options set to false' do
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: invalid_mixed_file }

        expect(assignment.criteria.pluck(:name)).not_to include('cr70')
      end

      it 'does not create criteria that have unmatched keys / more keys than required' do
        expect(assignment.criteria.where(type: 'RubricCriterion').length).to eq(1)
        post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                               upload_file: partially_valid_file }
        expect(assignment.criteria.where(type: 'RubricCriterion').length).to eq(1)
        expect(flash[:error]).not_to be_nil
      end

      context 'when there is no type specified for one of the criteria' do
        it 'flashes an error message' do
          post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                                 upload_file: no_type_file }
          expect(flash[:error]).not_to be_nil
        end
      end

      context 'When some criteria have been previously uploaded and and instructor performs a download' do
        it 'responds with appropriate status' do
          post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                                 upload_file: uploaded_file }

          get :download, params: { course_id: course.id, assignment_id: assignment.id }

          expect(response.status).to eq(200)
        end

        it 'sends the correct information' do
          post_as instructor, :upload, params: { course_id: course.id, assignment_id: assignment.id,
                                                 upload_file: test_upload_download_file }
          get :download, params: { course_id: course.id, assignment_id: assignment.id }

          expect(YAML.safe_load(response.body, permitted_classes: [Symbol], symbolize_names: true))
            .to eq(YAML.safe_load(expected_download.read, symbolize_names: true))
        end
      end
    end
  end

  context '#upload' do
    include_examples 'a controller supporting upload', formats: [:yml] do
      let(:params) { { course_id: course.id, assignment_id: assignment.id } }
    end
  end
end
