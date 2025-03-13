package net.atired.executiveorders.init;


import net.atired.executiveorders.ExecutiveOrders;
import net.atired.executiveorders.blocks.MonolithBlock;
import net.atired.executiveorders.blocks.VitricCampfireBlock;
import net.minecraft.block.*;
import net.minecraft.item.BlockItem;
import net.minecraft.item.Item;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.sound.BlockSoundGroup;
import net.minecraft.util.Identifier;

public class BlocksInit {
    public static final Block MONOLITH = new MonolithBlock(Block.Settings.create().strength(4.0f).nonOpaque().solidBlock(Blocks::never).blockVision(Blocks::never));
    public static final Block BEDROCK_LEAVES = new TranslucentBlock(Block.Settings.create().strength(2.0f).sounds(BlockSoundGroup.AZALEA_LEAVES).nonOpaque().solidBlock(Blocks::never).blockVision(Blocks::never));
    public static final Block VITRIC_CAMPFIRE = new VitricCampfireBlock(Block.Settings.create().strength(4.0f).sounds(BlockSoundGroup.WOOD).nonOpaque().solidBlock(Blocks::never).blockVision(Blocks::never).luminance(Blocks.createLightLevelFromLitBlockState(8)));

    private static void registerBlockItems(String name, Block block,Item.Settings settings){

        Registry.register(Registries.ITEM,ExecutiveOrders.id(name),new BlockItem(block,settings));
    }
    public static void register(){
        Registry.register(Registries.BLOCK, ExecutiveOrders.id("monolith"), MONOLITH);
        registerBlockItems("monolith",MONOLITH,new Item.Settings().fireproof());
        Registry.register(Registries.BLOCK, ExecutiveOrders.id("bedrock_leaves"), BEDROCK_LEAVES);
        registerBlockItems("bedrock_leaves",BEDROCK_LEAVES,new Item.Settings());
        Registry.register(Registries.BLOCK, ExecutiveOrders.id("vitric_campfire"), VITRIC_CAMPFIRE);
        registerBlockItems("vitric_campfire",VITRIC_CAMPFIRE,new Item.Settings());
    }
}
