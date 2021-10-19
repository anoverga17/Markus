describe Group do

  describe 'validations' do
    subject { build :group }

    it { is_expected.to belong_to(:course) }

    it { is_expected.to validate_presence_of(:group_name) }
    it { is_expected.to validate_uniqueness_of(:group_name).scoped_to(:course_id) }
    it { is_expected.to validate_length_of(:group_name).is_at_most(30) }

    it { is_expected.not_to allow_value('Mike !Ooh').for(:group_name) }
    it { is_expected.not_to allow_value('A!a.sa').for(:group_name) }
    it { is_expected.to allow_value('Ads_ -hb').for(:group_name) }
    it { is_expected.to allow_value('-22125-k1lj42_').for(:group_name) }

    it { is_expected.to allow_value('Mike !Ooh').for(:repo_name) }
    it { is_expected.to allow_value('A!a.sa').for(:repo_name) }
    it { is_expected.to allow_value('Ads_ -hb').for(:repo_name) }
    it { is_expected.to allow_value('-22125-k1lj42_').for(:repo_name) }

    it do
      is_expected.not_to allow_value('Mike !Ooh').for(:repo_name).on(:update)
      is_expected.not_to allow_value('A!a.sa').for(:repo_name).on(:update)
    end

    context 'fails when group_name is one of the reserved locations' do
      Repository.get_class.reserved_locations.each do |loc|
        it "#{loc}" do
          assignment = build(:group, group_name: loc)
          expect(assignment).not_to be_valid
        end
      end
    end
  end

  describe '#set_repo_name' do
    # The tests below are checking for a method that is called when
    # the group is initially created, so it is not explicitly called here.
    context 'when repository name is specified' do
      let(:group) { create(:group, repo_name: 'g2markus') }

      it 'sets repo_name to specified repository name' do
        expect(group.repo_name).to eq 'g2markus'
      end
    end

    context 'when repository name is not specified' do
      let(:group) { create(:group) }

      it 'sets repo_name to autogenerated repository name' do
        expect(group.repo_name).to start_with 'group_'
      end
    end
  end

  describe '#repository_relative_path' do
    let(:group) { create(:group, repo_name: 'g2markus') }

    it 'returns the group\'s repository name' do
      expect(group.repository_relative_path).to eq File.join(group.course.name, 'g2markus')
    end

    it 'rejects special chars repo_name' do
      expect(group.update(repo_name: 'group_!234')).to be false
    end
  end

  describe '#get_autogenerated_group_name' do
    let(:group) { create(:group) }

    it 'returns autogenerated group names' do
      expect(group.get_autogenerated_group_name).to start_with('group_')
    end
  end

  describe '#grouping_for_assignment' do
    let!(:grouping) { create(:grouping) }

    it 'returns the grouping for the specified assignment' do
      group = grouping.group
      assignment = grouping.assignment
      expect(group.grouping_for_assignment(assignment.id)).to eq grouping
    end
  end

  describe '#repository_external_access_url' do
    let(:group) { create(:group) }

    it 'returns the repository URL' do
      expect(group.repository_external_access_url).to end_with(group.repo_name)
    end

    it 'should contain the course name in the path' do
      expect(group.repository_external_access_url).to match("#{File::SEPARATOR}#{group.course.name}#{File::SEPARATOR}")
    end
  end

  describe '#build_repository' do
    let(:group) { create(:group) }

    it 'returns true' do
      expect(group.build_repository).to be_truthy
    end
  end

  describe '#access_repo' do
    context 'when repository exists' do
      let(:group) { create(:group) }

      it 'allows access to its repository' do
        group.access_repo do |repo|
          expect(repo).to be_truthy
          expect(repo.closed?).to be_falsey
        end
      end
    end
  end
end
