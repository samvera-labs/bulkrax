# frozen_string_literal: true

require 'rails_helper'

module Bulkrax
  RSpec.describe CsvFileSetEntry, type: :model do
    subject(:entry) { described_class.new }

    describe '#default_work_type' do
      subject { entry.default_work_type }
      it { is_expected.to eq("FileSet") }
    end

    describe '#file_reference' do
      context 'when parsed_metadata includes the "file" property' do
        before do
          entry.parsed_metadata = { 'file' => ['test.png'] }
        end

        it 'returns the correct key' do
          expect(entry.file_reference).to eq('file')
        end
      end

      context 'when parsed_metadata includes the "remote_files" property' do
        before do
          entry.parsed_metadata = { 'remote_files' => ['test.png'] }
        end

        it 'returns the correct key' do
          expect(entry.file_reference).to eq('remote_files')
        end
      end
    end

    describe '#validate_presence_of_parent!' do
      context 'when parent is missing' do
        before do
          entry.parsed_metadata = { 'remote_files' => ['test.png'] }
          allow(entry).to receive(:related_parents_parsed_mapping).and_return('parents')
        end
        it 'raises an error' do
          # entry.validate_presence_of_parent!
          expect { entry.validate_presence_of_parent! }.to raise_error(FileSetEntryBehavior::OrphanFileSetError, 'File set must be related to at least one work')
        end
      end
    end

    describe '#add_path_to_file' do
      context 'when file is not present' do
        subject(:entry) { described_class.new(importerexporter: FactoryBot.create(:bulkrax_importer_csv), type: "Bulkrax::CsvFileSetEntry") }

        before do
          entry.parsed_metadata = { 'file' => ['test.png'] }
          allow(entry.parser).to receive(:importer_unzip_path).and_return('some_real_path')
        end
        it 'raises an error' do
          expect { entry.add_path_to_file }.to raise_error(FileSetEntryBehavior::FilePathError, 'one or more file paths are invalid: test.png')
        end
      end
    end

    describe '#validate_presence_of_filename!' do
      context 'when filename is missing' do
        before do
          entry.parsed_metadata = {}
        end

        it 'raises a FileNameError' do
          expect { entry.validate_presence_of_filename! }
            .to raise_error(FileSetEntryBehavior::FileNameError, 'File set must have a filename')
        end
      end

      context 'when filename is present' do
        before do
          entry.parsed_metadata = { 'file' => ['test.png'] }
        end

        it 'does not raise an error' do
          expect { entry.validate_presence_of_filename! }
            .not_to raise_error
        end
      end

      context 'when filename is an array containing an empty string' do
        before do
          entry.parsed_metadata = { 'file' => [''] }
        end

        it 'raises a FileNameError' do
          expect { entry.validate_presence_of_filename! }
            .to raise_error(FileSetEntryBehavior::FileNameError, 'File set must have a filename')
        end
      end
    end

    describe 'relating and visibility' do
      subject(:entry) do
        described_class.create!(identifier: 'file_set_entry', importerexporter: importer, parsed_metadata: { 'parents' => parents })
      end

      let(:importer) { FactoryBot.create(:bulkrax_importer_csv_complex) }
      let(:parents) { ['work_entry', 'other_work_entry'] }
      let(:relationships) { PendingRelationship.where(child_id: 'file_set_entry') }

      before { FactoryBot.create(:bulkrax_importer_run, importer: importer) }

      context 'with the ActiveFedora object factory, which attaches the file set itself' do
        it 'records no pending relationship' do
          expect(entry.parent_jobs).to be false
          expect(relationships).to be_empty
        end

        it "gives a file set without a visibility the importer's" do
          entry.parsed_metadata['visibility'] = ''
          entry.add_visibility

          expect(entry.parsed_metadata['visibility']).to eq importer.visibility
        end
      end

      context 'with the Valkyrie object factory, which leaves the file set for CreateRelationshipsJob' do
        before { allow(Bulkrax).to receive(:object_factory).and_return(ValkyrieObjectFactory) }

        it 'records a pending relationship to the first parent only, the one the file set is created for' do
          entry.parent_jobs

          expect(relationships.pluck(:parent_id, :importer_run_id)).to eq [['work_entry', importer.last_run.id]]
        end

        it 'records none to a parent the import deletes' do
          entry.define_singleton_method(:deleted_identifier?) { |identifier| identifier == 'work_entry' }
          entry.parent_jobs

          expect(relationships).to be_empty
        end

        it "leaves a blank visibility blank, so the file set takes its work's" do
          entry.parsed_metadata['visibility'] = ''
          entry.add_visibility

          expect(entry.parsed_metadata).not_to have_key('visibility')
        end

        it "keeps the row's visibility" do
          entry.parsed_metadata['visibility'] = 'restricted'
          entry.add_visibility

          expect(entry.parsed_metadata['visibility']).to eq 'restricted'
        end
      end
    end
  end
end
