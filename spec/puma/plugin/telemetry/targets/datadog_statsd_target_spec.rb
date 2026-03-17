# frozen_string_literal: true

require 'spec_helper'
require 'socket'

module Puma
  class Plugin
    module Telemetry
      module Targets
        RSpec.describe DatadogStatsdTarget do
          subject(:target) { described_class.new(client: client) }

          let(:client) { instance_double('Datadog::Statsd') }

          before do
            allow(client).to receive(:gauge)
            allow(client).to receive(:flush)
            allow(Socket).to receive(:gethostname).and_return('test-host')
          end

          describe '#call' do
            context 'with requests_inflight metric' do
              let(:telemetry) { { 'requests_inflight' => 5 } }

              it 'emits with pod hostname tag' do
                target.call(telemetry)
                expect(client).to have_received(:gauge).with(
                  'requests_inflight',
                  5,
                  tags: ['pod:test-host']
                )
              end
            end

            context 'with other metrics' do
              let(:telemetry) { { 'queue.backlog' => 10 } }

              it 'emits without tags' do
                target.call(telemetry)
                expect(client).to have_received(:gauge).with('queue.backlog', 10)
              end
            end

            context 'with mixed metrics' do
              let(:telemetry) do
                {
                  'requests_inflight' => 5,
                  'queue.backlog' => 10,
                  'workers.spawned_threads' => 8
                }
              end

              it 'tags only requests_inflight' do
                target.call(telemetry)

                expect(client).to have_received(:gauge).with(
                  'requests_inflight', 5, tags: ['pod:test-host']
                )
                expect(client).to have_received(:gauge).with('queue.backlog', 10)
                expect(client).to have_received(:gauge).with('workers.spawned_threads', 8)
              end
            end

            it 'flushes after emitting all metrics' do
              target.call({ 'queue.backlog' => 1 })
              expect(client).to have_received(:flush).with(sync: true)
            end
          end

          describe 'hostname caching' do
            before { target } # Force subject instantiation before assertions

            it 'retrieves hostname once during initialization' do
              expect(Socket).to have_received(:gethostname).once
            end

            it 'does not call gethostname on each call' do
              target.call({ 'requests_inflight' => 1 })
              target.call({ 'requests_inflight' => 2 })
              expect(Socket).to have_received(:gethostname).once
            end
          end
        end
      end
    end
  end
end
