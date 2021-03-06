# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Comments
    describe CommentsController, type: :controller do
      routes { Decidim::Comments::Engine.routes }

      let(:organization) { create(:organization) }
      let(:participatory_process) { create :participatory_process, organization: organization }
      let(:component) { create(:component, participatory_space: participatory_process) }
      let(:commentable) { create(:dummy_resource, component: component) }

      before do
        request.env["decidim.current_organization"] = organization
      end

      describe "GET index" do
        it "renders the index template" do
          get :index, xhr: true, params: { commentable_gid: commentable.to_signed_global_id.to_s }
          expect(subject).to render_template(:index)
        end

        context "when the reload parameter is given" do
          it "renders the reload template" do
            get :index, xhr: true, params: { commentable_gid: commentable.to_signed_global_id.to_s, reload: 1 }
            expect(subject).to render_template(:reload)
          end
        end

        context "when comments are disabled for the component" do
          let(:component) { create(:component, :with_comments_disabled, participatory_space: participatory_process) }

          it "redirects with a flash alert" do
            get :index, xhr: true, params: { commentable_gid: commentable.to_signed_global_id.to_s }
            expect(flash[:alert]).to be_present
            expect(response).to have_http_status(:redirect)
          end
        end
      end

      describe "POST create" do
        let(:comment_alignment) { 0 }
        let(:comment_params) do
          {
            commentable_gid: commentable.to_signed_global_id.to_s,
            body: "This is a new comment",
            alignment: comment_alignment
          }
        end

        it "responds with unauthorized status" do
          post :create, xhr: true, params: { comment: comment_params }
          expect(response).to have_http_status(:unauthorized)
        end

        context "when the user is signed in" do
          let(:user) { create(:user, :confirmed, locale: "en", organization: organization) }
          let(:comment) { Decidim::Comments::Comment.last }

          before do
            sign_in user, scope: :user
          end

          it "creates the comment" do
            expect do
              post :create, xhr: true, params: { comment: comment_params }
            end.to change { Decidim::Comments::Comment.count }.by(1)

            expect(comment.body.values.first).to eq("This is a new comment")
            expect(comment.alignment).to eq(comment_alignment)
            expect(subject).to render_template(:create)
          end

          context "when comments are disabled for the component" do
            let(:component) { create(:component, :with_comments_disabled, participatory_space: participatory_process) }

            it "redirects with a flash alert" do
              post :create, xhr: true, params: { comment: comment_params }
              expect(flash[:alert]).to be_present
              expect(response).to have_http_status(:redirect)
            end
          end

          context "when trying to comment on a private space where the user is not assigned to" do
            let(:participatory_process) { create :participatory_process, :private, organization: organization }

            it "redirects with a flash alert" do
              post :create, xhr: true, params: { comment: comment_params }
              expect(flash[:alert]).to be_present
              expect(response).to have_http_status(:redirect)
            end
          end

          context "when comment alignment is positive" do
            let(:comment_alignment) { 1 }

            it "creates the comment with the alignment defined as 1" do
              expect do
                post :create, xhr: true, params: { comment: comment_params }
              end.to change { Decidim::Comments::Comment.count }.by(1)

              expect(comment.alignment).to eq(comment_alignment)
              expect(subject).to render_template(:create)
            end
          end

          context "when comment alignment is negative" do
            let(:comment_alignment) { -1 }

            it "creates the comment with the alignment defined as -1" do
              expect do
                post :create, xhr: true, params: { comment: comment_params }
              end.to change { Decidim::Comments::Comment.count }.by(1)

              expect(comment.alignment).to eq(comment_alignment)
              expect(subject).to render_template(:create)
            end
          end

          context "when comment body is missing" do
            let(:comment_params) do
              {
                commentable_gid: commentable.to_signed_global_id.to_s,
                alignment: comment_alignment
              }
            end

            it "renders the error template" do
              post :create, xhr: true, params: { comment: comment_params }
              expect(subject).to render_template(:error)
            end
          end

          context "when comment alignment is invalid" do
            let(:comment_alignment) { 2 }

            it "renders the error template" do
              post :create, xhr: true, params: { comment: comment_params }
              expect(subject).to render_template(:error)
            end
          end

          context "when the comment does not exist" do
            let(:comment_params) do
              {
                commentable_gid: "unexisting",
                body: "This is a new comment",
                alignment: 0
              }
            end

            it "raises a routing error" do
              expect do
                post :create, xhr: true, params: { comment: comment_params }
              end.to raise_error(ActionController::RoutingError)
            end
          end
        end
      end
    end
  end
end
