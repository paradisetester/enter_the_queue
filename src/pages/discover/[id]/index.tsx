import Layout from "../../../components/Layout"
import { getNftById } from "../../../services";
import NFTDetail from "../../../components/nft/NFTDetails";
import { useEffect, useState } from "react";
import { getBaseUrl } from "helpers/axios";

interface NFTDetailProps {
    nftItem: any;
    id: string;
}

export default function BaseNftDetail({ id }: NFTDetailProps) {

    const [nft, setNft] = useState<any>(false);
    const [isLoading, setIsLoading] = useState<Boolean>(false);
    const [updated, setUpdated] = useState<Boolean>(false);

    useEffect(() => {
        (async () => {
            setIsLoading(true);
            const nftDetails: any = await getNftById(id);
            if(Object.keys(nftDetails).length) {
                setNft(nftDetails);
            }            
            setIsLoading(false);
        })();
    }, [id, updated]);

    return (
        <Layout isLoading={isLoading} is404={!nft}>
            <NFTDetail useUpdate={[updated, setUpdated]} details={nft} />
        </Layout>
    )
}

export const getServerSideProps = async (context: any) => {
    const { id }: any = context.query;
    const nft = await fetch(getBaseUrl(`api/nfts/${id}`))
        .then(res => res.json())
        .then(res => res.data);
        
    if (Object.keys(nft).length) {
        return { props: { nft, id: id } };
    }
    return {
        notFound: true
    }
}
