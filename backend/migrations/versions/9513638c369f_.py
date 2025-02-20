"""empty message

Revision ID: 9513638c369f
Revises: 262db18d21a7
Create Date: 2024-09-06 21:51:08.279320

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '9513638c369f'
down_revision = '262db18d21a7'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table('secondary_approvers', schema=None) as batch_op:
        batch_op.drop_column('approved_at')

    with op.batch_alter_table('waybill_log', schema=None) as batch_op:
        batch_op.drop_column('approved_by')
        batch_op.drop_column('approval_status')
        batch_op.drop_column('approval_time')

    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table('waybill_log', schema=None) as batch_op:
        batch_op.add_column(sa.Column('approval_time', sa.DATETIME(), nullable=True))
        batch_op.add_column(sa.Column('approval_status', sa.VARCHAR(length=50), nullable=True))
        batch_op.add_column(sa.Column('approved_by', sa.VARCHAR(length=50), nullable=True))

    with op.batch_alter_table('secondary_approvers', schema=None) as batch_op:
        batch_op.add_column(sa.Column('approved_at', sa.DATETIME(), nullable=True))

    # ### end Alembic commands ###
