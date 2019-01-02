require 'rails_helper'

module DelayHenka
  RSpec.describe ApplyChangesWorker do

    describe '#perform' do
      let!(:changeable){ Foo.create(attr_chars: 'hello') }

      it 'updates state of replaced changes' do
        ScheduledChange.create(changeable: changeable, submitted_by_id: 10, attribute_name: 'attr_chars', old_value: 'hello', new_value: 'world')
        ScheduledChange.create(changeable: changeable, submitted_by_id: 10, attribute_name: 'attr_int', old_value: nil, new_value: 5)

        Sidekiq::Testing.inline! do
          expect{ described_class.perform_async }
            .to change{ changeable.reload.attr_chars }.from('hello').to('world')
            .and change{ changeable.reload.attr_int }.from(nil).to(5)
        end
      end

      it 'does not apply replaced changes' do
        change_1 = ScheduledChange.create(changeable: changeable, submitted_by_id: 10, attribute_name: 'attr_chars', old_value: 'hello', new_value: 'w1')
        change_2 = ScheduledChange.create(changeable: changeable, submitted_by_id: 10, attribute_name: 'attr_chars', old_value: 'hello', new_value: 'w2')
        Sidekiq::Testing.inline! do
          expect{ described_class.perform_async }
            .to change{ changeable.reload.attr_chars }.from('hello').to('w2')
            .and change{ change_1.reload.state }.to(DelayHenka::ScheduledChange::STATES[:REPLACED])
            .and change{ change_2.reload.state }.to(DelayHenka::ScheduledChange::STATES[:COMPLETED])
        end
      end
    end

  end
end
