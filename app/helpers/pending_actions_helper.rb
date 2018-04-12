module PendingActionsHelper
  private

  def accept_pending_memberships
    if current_user.is_logged_in?
      consume_pending_group(current_user)
      consume_pending_membership(current_user)
    end
  end

  def handle_pending_actions(user)
    return unless user.presence

    session.delete(:pending_user_id) if pending_user

    consume_pending_login_token
    consume_pending_identity(user)
    consume_pending_group(user)
    consume_pending_membership(user)
  end

  def consume_pending_login_token
    if pending_token
      pending_token.update(used: true)
      session.delete(:pending_token)
    end
  end

  def consume_pending_identity(user)
    if pending_identity
      user.associate_with_identity(pending_identity)
      session.delete(:pending_identity_id)
    end
  end

  def consume_pending_group(user)
    if pending_group
      membership = pending_group.memberships.build(user: user)
      MembershipService.redeem(membership: membership, actor: user)
      session.delete(:pending_group_token)
    end
  end

  def consume_pending_membership(user)
    if pending_membership
      MembershipService.redeem(membership: pending_membership, actor: user)
      session.delete(:pending_membership_token)
    end
  end

  def pending_group
    @pending_group ||= Group.find_by(token: session[:pending_group_token]) if session[:pending_group_token]
  end

  def pending_token
    @pending_token_user ||= LoginToken.where.not(user_id: current_user.email_verified? && current_user.id).find_by(token: session[:pending_token]) if session[:pending_token]
  end

  def pending_membership
    @pending_membership ||= Membership.find_by(token: session[:pending_membership_token]) if session[:pending_membership_token]
  end

  def pending_identity
    @pending_identity ||= Identities::Base.find_by(id: session[:pending_identity_id]) if session[:pending_identity_id]
  end

  def pending_user
    @pending_user ||= User.find_by(id: session[:pending_user_id]) if session[:pending_user_id]
  end

  def serialized_pending_identity
    Pending::TokenSerializer.new(pending_token, root: false).as_json ||
    Pending::IdentitySerializer.new(pending_identity, root: false).as_json ||
    Pending::MembershipSerializer.new(pending_membership, root: false).as_json ||
    Pending::GroupSerializer.new(pending_group, root: false).as_json ||
    Pending::UserSerializer.new(pending_user, root: false).as_json || {}
  end
end
