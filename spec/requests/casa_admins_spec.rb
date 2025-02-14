require "rails_helper"

RSpec.describe "/casa_admins", type: :request do
  describe "GET /casa_admins/:id/edit" do
    context "logged in as admin user" do
      it "can successfully access a casa admin edit page" do
        sign_in_as_admin

        get edit_casa_admin_path(create(:casa_admin))

        expect(response).to be_successful
      end
    end

    context "logged in as a non-admin user" do
      it "cannot access a casa admin edit page" do
        sign_in_as_volunteer

        get edit_casa_admin_path(create(:casa_admin))

        expect(response).to redirect_to root_path
        expect(response.request.flash[:notice]).to eq "Sorry, you are not authorized to perform this action."
      end
    end

    context "unauthenticated request" do
      it "cannot access a casa admin edit page" do
        get edit_casa_admin_path(create(:casa_admin))

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "PUT /casa_admins/:id" do
    context "logged in as admin user" do
      let(:casa_admin) { create(:casa_admin) }
      let(:expected_display_name) { "Admin 2" }
      let(:expected_email) { "admin2@casa.com" }

      before do
        sign_in_as_admin
      end

      it "can successfully update a casa admin user", :aggregate_failures do
        put casa_admin_path(casa_admin), params: {
          casa_admin: {
            email: expected_email,
            display_name: expected_display_name
          }
        }

        casa_admin.reload
        expect(casa_admin.email).to eq expected_email
        expect(casa_admin.display_name).to eq expected_display_name
        expect(response).to redirect_to casa_admins_path
        expect(response.request.flash[:notice]).to eq "New admin created successfully"
      end

      it "also respond as json", :aggregate_failures do
        put casa_admin_path(casa_admin, format: :json), params: {
          casa_admin: {
            email: expected_email,
            display_name: expected_display_name
          }
        }

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(expected_email.to_json)
      end
    end

    context "when logged in as admin, but invalid data" do
      let(:casa_admin) { create(:casa_admin) }

      before do
        sign_in_as_admin
      end

      it "cannot update the casa admin", :aggregate_failures do
        put casa_admin_path(casa_admin), params: {
          casa_admin: {email: nil}
        }

        casa_admin.reload
        expect(casa_admin.email).not_to eq nil
        expect(response).to render_template :edit
      end

      it "also respond as json", :aggregate_failures do
        put casa_admin_path(casa_admin, format: :json), params: {
          casa_admin: {email: nil}
        }

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match("Email can't be blank".to_json)
      end
    end

    context "logged in as a non-admin user" do
      it "cannot update a casa admin user" do
        sign_in_as_volunteer

        put casa_admin_path(create(:casa_admin)), params: {
          casa_admin: {
            email: "admin@casa.com",
            display_name: "The admin"
          }
        }

        expect(response).to redirect_to root_path
        expect(response.request.flash[:notice]).to eq "Sorry, you are not authorized to perform this action."
      end
    end

    context "unauthenticated request" do
      it "cannot update a casa admin user" do
        put casa_admin_path(create(:casa_admin)), params: {
          casa_admin: {
            email: "admin@casa.com",
            display_name: "The admin"
          }
        }

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "PATCH /activate" do
    let(:casa_admin) { create(:casa_admin, active: false) }

    context "when successfully" do
      before { sign_in_as_admin }

      it "activates an inactive casa_admin" do
        patch activate_casa_admin_path(casa_admin)

        casa_admin.reload
        expect(casa_admin.active).to eq(true)
      end

      it "sends an activation email" do
        expect { patch activate_casa_admin_path(casa_admin) }
          .to change { ActionMailer::Base.deliveries.count }
          .by(1)
      end

      it "also respond as json", :aggregate_failures do
        patch activate_casa_admin_path(casa_admin, format: :json)

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:ok)
        expect(response.body).to match(casa_admin.reload.active.to_json)
      end
    end

    context "when occurs send errors" do
      before do
        sign_in_as_admin
      end

      it "redirects to admin edition page" do
        allow(CasaAdminMailer).to receive_message_chain(:account_setup, :deliver) { raise Errno::ECONNREFUSED }

        patch activate_casa_admin_path(casa_admin)

        expect(response).to redirect_to(edit_casa_admin_path(casa_admin))
      end

      it "shows error message" do
        allow(CasaAdminMailer).to receive_message_chain(:account_setup, :deliver) { raise Errno::ECONNREFUSED }

        patch activate_casa_admin_path(casa_admin)

        expect(flash[:alert]).to eq("Email not sent.")
      end

      it "also respond as json", :aggregate_failures do
        casa_admin = create(:casa_admin, active: false)
        allow_any_instance_of(CasaAdmin).to receive(:activate).and_return(false)
        allow_any_instance_of(CasaAdmin).to receive_message_chain(:errors, :full_messages)
          .and_return ["Error message test"]

        patch activate_casa_admin_path(casa_admin, format: :json)

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match("Error message test".to_json)
      end
    end
  end

  describe "PATCH /casa_admins/:id/deactivate" do
    let(:casa_admin) { create(:casa_admin, active: true) }

    context "logged in as admin user" do
      context "when successfully" do
        before { sign_in_as_admin }

        it "can successfully deactivate a casa admin user" do
          patch deactivate_casa_admin_path(casa_admin)
          casa_admin.reload
          expect(casa_admin.active).to be_falsey

          expect(response).to redirect_to edit_casa_admin_path(casa_admin)
          expect(response.request.flash[:notice]).to eq "Admin was deactivated."
        end

        it "sends a deactivation email" do
          expect { patch deactivate_casa_admin_path(casa_admin) }
            .to change { ActionMailer::Base.deliveries.count }
            .by(1)
        end

        it "also respond as json", :aggregate_failures do
          patch deactivate_casa_admin_path(casa_admin, format: :json)

          expect(response.content_type).to eq("application/json; charset=utf-8")
          expect(response).to have_http_status(:ok)
          expect(response.body).to match(casa_admin.reload.active.to_json)
        end
      end

      context "when occurs send errors" do
        before { sign_in_as_admin }

        it "redirects to admin edition page" do
          allow(CasaAdminMailer).to receive_message_chain(:deactivation, :deliver) { raise Errno::ECONNREFUSED }

          patch deactivate_casa_admin_path(casa_admin)

          expect(response).to redirect_to(edit_casa_admin_path(casa_admin))
        end

        it "shows error message" do
          allow(CasaAdminMailer).to receive_message_chain(:deactivation, :deliver) { raise Errno::ECONNREFUSED }

          patch deactivate_casa_admin_path(casa_admin)

          expect(flash[:alert]).to eq("Email not sent.")
        end

        it "also respond as json", :aggregate_failures do
          casa_admin = create(:casa_admin, active: true)
          allow_any_instance_of(CasaAdmin).to receive(:deactivate).and_return(false)
          allow_any_instance_of(CasaAdmin).to receive_message_chain(:errors, :full_messages)
            .and_return ["Error message test"]

          patch deactivate_casa_admin_path(casa_admin, format: :json)

          expect(response.content_type).to eq("application/json; charset=utf-8")
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match("Error message test".to_json)
        end
      end
    end

    context "logged in as a non-admin user" do
      it "cannot update a casa admin user" do
        sign_in_as_volunteer

        patch deactivate_casa_admin_path(create(:casa_admin))

        expect(response).to redirect_to root_path
        expect(response.request.flash[:notice]).to eq "Sorry, you are not authorized to perform this action."
      end
    end

    context "unauthenticated request" do
      it "cannot update a casa admin user" do
        patch deactivate_casa_admin_path(create(:casa_admin))

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "PATCH /resend_invitation" do
    let(:casa_admin) { create(:casa_admin, active: true) }

    before { sign_in_as_admin }
    it "resends an invitation email" do
      expect(casa_admin.invitation_created_at.present?).to eq(false)

      patch resend_invitation_casa_admin_path(casa_admin)
      casa_admin.reload

      expect(casa_admin.invitation_created_at.present?).to eq(true)
      expect(Devise.mailer.deliveries.count).to eq(1)
      expect(Devise.mailer.deliveries.first.subject).to eq(I18n.t("devise.mailer.invitation_instructions.subject"))
      expect(response).to redirect_to(edit_casa_admin_path(casa_admin))
    end
  end

  describe "POST /casa_admins" do
    subject { post casa_admins_path, params: {casa_admin: params} }

    before { sign_in_as_admin }

    context "when successfully" do
      let(:params) { attributes_for(:casa_admin) }

      it "creates a new casa_admin" do
        expect { subject }.to change(CasaAdmin, :count).by(1)
      end

      it "has flash notice" do
        subject

        expect(flash[:notice]).to eq("New admin created successfully")
      end

      it "redirects to casa_admins_path" do
        subject

        expect(response).to redirect_to casa_admins_path
      end

      it "also respond to json", :aggregate_failures do
        post casa_admins_path(format: :json), params: {casa_admin: params}

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:created)
        expect(response.body).to match(params[:display_name].to_json)
      end
    end

    context "when failure" do
      let(:params) { attributes_for(:casa_admin) }

      before do
        allow_any_instance_of(CreateCasaAdminService).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it "does not create a new casa_admin" do
        expect { subject }.not_to change(CasaAdmin, :count)
      end

      it "renders new_casa_admin_path" do
        subject

        expect(response).to render_template :new
      end

      it "also respond to json", :aggregate_failures do
        casa_admin = instance_spy(CasaAdmin)
        allow(casa_admin).to receive_message_chain(:errors, :full_messages).and_return(["Some error message"])
        allow_any_instance_of(CreateCasaAdminService).to receive(:casa_admin).and_return(casa_admin)

        post casa_admins_path(format: :json), params: {casa_admin: params}

        expect(response.content_type).to eq("application/json; charset=utf-8")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match("Some error message".to_json)
      end
    end
  end
end
